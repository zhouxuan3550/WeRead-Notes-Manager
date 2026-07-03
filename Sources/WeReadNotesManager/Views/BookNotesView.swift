import AppKit
import SwiftUI

struct BookNotesView: View {
    let book: Book
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.themePalette) private var palette
    @State private var selectedChapter = "全部"
    @State private var selectedNote: ReadingNote?
    @State private var askAINote: ReadingNote?
    @State private var aiTextRequest: AITextRequest?
    @State private var cardTemplate: ReadingCardTemplate = .dark
    @State private var exportError: String?
    @State private var showBookSummary = false

    var body: some View {
        HStack(spacing: 0) {
            chapterSidebar
                .frame(width: 270)

            PremiumDivider()

            noteStream
                .frame(minWidth: 520, maxWidth: .infinity)
                .layoutPriority(1)

            PremiumDivider()

            inspector
                .frame(width: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            restoreReadingPosition()
        }
        .onChange(of: selectedChapter) { _, _ in
            selectedNote = filteredNotes.first
            saveReadingPosition()
        }
        .onChange(of: selectedNote?.id) { _, _ in
            saveReadingPosition()
        }
        .sheet(item: $askAINote) { note in
            AskAIView(note: note)
        }
        .sheet(item: $aiTextRequest) { request in
            AITextWorkbenchView(request: request)
        }
        .sheet(isPresented: $showBookSummary) {
            BookSummaryView(book: book)
        }
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("好") {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private var chapterSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                BookCoverView(book: book, size: .medium)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(3)
                    Text(book.author ?? "未知作者")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                statPill("\(book.notes.count)", "摘录")
                statPill("\(thoughtCount)", "想法")
            }

            Text("章节")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    chapterButton(title: "全部", count: book.notes.count)
                    ForEach(chapterGroups, id: \.title) { group in
                        chapterButton(title: group.title, count: group.notes.count)
                    }
                }
            }

            Spacer()

            if let noteURL = firstOpenURL {
                Button {
                    NSWorkspace.shared.open(noteURL)
                } label: {
                    Label("打开微信读书", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .flatActionButton(height: 32)

                // 同步到外部工具
                Menu {
                    ForEach(ExternalSyncService.Destination.allCases) { dest in
                        Button {
                            ExternalSyncService.saveToFile(book: book, destination: dest)
                        } label: {
                            Label("导出为 \(dest.label)", systemImage: dest.systemImage)
                        }
                        Button {
                            ExternalSyncService.copyToClipboard(book: book, destination: dest)
                        } label: {
                            Label("复制 \(dest.label) 格式", systemImage: "doc.on.doc")
                        }
                    }
                } label: {
                    Label("同步到外部", systemImage: "arrow.triangle.branch")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(palette.surfaceElevated)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.borderSubtle, lineWidth: 0.5))
                )
            }
        }
        .padding(18)
    }

    private var noteStream: some View {
        VStack(spacing: 0) {
            HStack {
                BookNotesIconButton(systemImage: "chevron.left", title: "返回书架") {
                    appVM.selectedBook = nil
                    appVM.selectedSidebarItem = .books
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedChapter == "全部" ? "全书摘录" : selectedChapter)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("\(filteredNotes.count) 条，按章节和位置排序")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Spacer()

                BookNotesIconButton(systemImage: "chevron.up", title: "上一条") {
                    goToPreviousNote()
                }
                .disabled(previousNote == nil)

                BookNotesIconButton(systemImage: "chevron.down", title: "下一条") {
                    goToNextNote()
                }
                .disabled(nextNote == nil)

                BookNotesIconButton(systemImage: "square.grid.3x3", title: "导出卡片组") {
                    do {
                        try ReadingCardExporter.exportBatch(notes: Array(filteredNotes.prefix(9)), template: cardTemplate)
                    } catch {
                        exportError = error.localizedDescription
                    }
                }
                .disabled(filteredNotes.isEmpty)
            }
            .padding(18)

            PremiumDivider()

            if filteredNotes.isEmpty {
                EmptyStateView(
                    title: "本章没有摘录",
                    subtitle: "这本书在当前章节下没有笔记，换个章节看看",
                    systemImage: "note.text"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredNotes) { note in
                            Button {
                                selectedNote = note
                            } label: {
                                BookReaderRow(note: note, isSelected: selectedNote?.id == note.id)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contextMenu {
                                Button("问 AI") { askAINote = note }
                                Button(note.isFavorite ? "取消收藏" : "收藏") { appVM.toggleFavorite(note) }
                                Button("打开详情") {
                                    appVM.selectedNote = note
                                    appVM.selectedBook = book
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(18)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let note = selectedNote {
                Text("当前摘录")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                if let positionText {
                    Text(positionText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textTertiary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(note.chapter ?? "未分章")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                    Text(note.highlight)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.textPrimary)
                        .lineSpacing(4)
                        .lineLimit(8)
                    if let userNote = note.userNote, !userNote.isEmpty {
                        Divider()
                            .background(palette.borderSubtle)
                        Text(userNote)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(5)
                    }
                }
                .padding(12)
                .glassPanel()

                VStack(alignment: .leading, spacing: 8) {
                    inspectorRow("位置", note.location ?? "-")
                    if let createdAt = note.createdAt {
                        inspectorRow("创建", createdAt.shortString)
                    }
                    inspectorRow("复习", "\(note.reviewCount) 次")
                    inspectorRow("收藏", note.isFavorite ? "是" : "否")
                }
                .padding(12)
                .glassPanel()

                Picker("卡片模板", selection: $cardTemplate) {
                    ForEach(ReadingCardTemplate.allCases) { template in
                        Text(template.label).tag(template)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    askAINote = note
                } label: {
                    Label("问 AI", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .flatActionButton(height: 32)

                Button {
                    aiTextRequest = makeChapterSummaryRequest()
                } label: {
                    Label(selectedChapter == "全部" ? "总结全书" : "总结本章", systemImage: "sparkles.rectangle.stack")
                        .frame(maxWidth: .infinity)
                }
                .flatActionButton(height: 32)

                Button {
                    aiTextRequest = makeBatchQuestionRequest()
                } label: {
                    Label("批量追问", systemImage: "text.bubble")
                        .frame(maxWidth: .infinity)
                }
                .flatActionButton(height: 32)

                Button {
                    showBookSummary = true
                } label: {
                    Label("AI 总结本书", systemImage: "doc.text.image")
                        .frame(maxWidth: .infinity)
                }
                .flatActionButton(height: 32)

                Button {
                    do {
                        try ReadingCardExporter.export(note: note, template: cardTemplate)
                    } catch {
                        exportError = error.localizedDescription
                    }
                } label: {
                    Label("导出卡片", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .flatActionButton(height: 32)

                Button {
                    appVM.selectedBook = book
                    appVM.selectedNote = note
                } label: {
                    Label("打开详情阅读", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .flatActionButton(height: 32)

                Spacer()
            } else {
                EmptyStateView(
                    title: "选择一条摘录",
                    subtitle: "在左侧列表中点击任意笔记查看详情",
                    systemImage: "text.quote"
                )
            }
        }
        .padding(18)
    }

    private func chapterButton(title: String, count: Int) -> some View {
        Button {
            selectedChapter = title
        } label: {
            HStack {
                Text(title)
                    .lineLimit(1)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedChapter == title ? palette.selectionBackground : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func statPill(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 16, weight: .bold))
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(palette.surfaceElevated)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.borderSubtle, lineWidth: 0.5))
        )
    }

    private func inspectorRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(palette.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
        }
        .font(.system(size: 12))
    }

    private var filteredNotes: [ReadingNote] {
        if selectedChapter == "全部" {
            return orderedNotes
        }
        return orderedNotes.filter { ($0.chapter?.isEmpty == false ? $0.chapter! : "未分章") == selectedChapter }
    }

    private var orderedNotes: [ReadingNote] {
        book.notes.sorted {
            let left = "\($0.chapter ?? "未分章")|\($0.location ?? "")|\($0.createdAt?.timeIntervalSince1970 ?? 0)"
            let right = "\($1.chapter ?? "未分章")|\($1.location ?? "")|\($1.createdAt?.timeIntervalSince1970 ?? 0)"
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }

    private var chapterGroups: [(title: String, notes: [ReadingNote])] {
        let grouped = Dictionary(grouping: orderedNotes) { $0.chapter?.isEmpty == false ? $0.chapter! : "未分章" }
        return grouped.map { ($0.key, $0.value) }.sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
    }

    private var thoughtCount: Int {
        book.notes.filter { $0.userNote?.isEmpty == false || $0.noteKind == "thought" || $0.noteKind == "review" }.count
    }

    private var firstOpenURL: URL? {
        if let sourceURL = book.notes.first(where: { $0.sourceURL != nil })?.sourceURL {
            return URL(string: sourceURL)
        }
        return nil
    }

    private var selectedIndex: Int? {
        guard let selectedNote else { return nil }
        return filteredNotes.firstIndex { $0.id == selectedNote.id }
    }

    private var previousNote: ReadingNote? {
        guard let selectedIndex, selectedIndex > 0 else { return nil }
        return filteredNotes[selectedIndex - 1]
    }

    private var nextNote: ReadingNote? {
        guard let selectedIndex, selectedIndex + 1 < filteredNotes.count else { return nil }
        return filteredNotes[selectedIndex + 1]
    }

    private var positionText: String? {
        guard let selectedIndex else { return nil }
        return "第 \(selectedIndex + 1) / \(filteredNotes.count) 条"
    }

    private func goToPreviousNote() {
        if let previousNote {
            selectedNote = previousNote
        }
    }

    private func goToNextNote() {
        if let nextNote {
            selectedNote = nextNote
        }
    }

    private var readingPositionKey: String {
        "bookReaderPosition.\(book.id.uuidString)"
    }

    private var readingChapterKey: String {
        "bookReaderChapter.\(book.id.uuidString)"
    }

    private func restoreReadingPosition() {
        let savedChapter = UserDefaults.standard.string(forKey: readingChapterKey)
        if let savedChapter, savedChapter == "全部" || chapterGroups.contains(where: { $0.title == savedChapter }) {
            selectedChapter = savedChapter
        }
        if let noteIDString = UserDefaults.standard.string(forKey: readingPositionKey),
           let noteID = UUID(uuidString: noteIDString),
           let note = filteredNotes.first(where: { $0.id == noteID }) {
            selectedNote = note
        } else if selectedNote == nil {
            selectedNote = filteredNotes.first
        }
    }

    private func saveReadingPosition() {
        UserDefaults.standard.set(selectedChapter, forKey: readingChapterKey)
        if let selectedNote {
            UserDefaults.standard.set(selectedNote.id.uuidString, forKey: readingPositionKey)
        }
    }

    private func makeChapterSummaryRequest() -> AITextRequest {
        let title = selectedChapter == "全部" ? "总结《\(book.title)》" : "总结章节：\(selectedChapter)"
        let notes = Array(filteredNotes.prefix(80))
        return AITextRequest(
            title: title,
            context: notesContext(notes),
            defaultQuestion: selectedChapter == "全部"
                ? "请基于这些书摘总结这本书的核心观点、反复出现的主题，以及我可能最应该复习的 5 个问题。"
                : "请总结本章这些书摘的主线、关键洞见，并提出 5 个适合继续思考的问题。"
        )
    }

    private func makeBatchQuestionRequest() -> AITextRequest {
        AITextRequest(
            title: "批量追问：\(selectedChapter == "全部" ? book.title : selectedChapter)",
            context: notesContext(Array(filteredNotes.prefix(60))),
            defaultQuestion: "请把这些书摘合并分析，找出它们之间的共同问题、矛盾点和可以延展成文章的 3 个主题。"
        )
    }

    private func notesContext(_ notes: [ReadingNote]) -> String {
        var lines = ["书名：\(book.title)", "作者：\(book.author ?? "未知")", "范围：\(selectedChapter)", ""]
        for (index, note) in notes.enumerated() {
            lines.append("\(index + 1). \(note.chapter ?? "未分章")：\(note.highlight)")
            if let userNote = note.userNote, !userNote.isEmpty {
                lines.append("   我的想法：\(userNote)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

private struct BookReaderRow: View {
    let note: ReadingNote
    let isSelected: Bool
    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(note.chapter ?? "未分章")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
                Spacer()
                if note.userNote?.isEmpty == false {
                    Image(systemName: "quote.bubble")
                        .foregroundStyle(palette.textTertiary)
                }
                if note.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(palette.accent)
                }
            }

            Text(note.highlight)
                .font(.system(size: 14))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(3)
                .lineLimit(4)

            if let userNote = note.userNote, !userNote.isEmpty {
                Text(userNote)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? palette.selectionBackground : palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? palette.accent.opacity(0.40) : palette.borderSubtle, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BookNotesIconButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    @Environment(\.themePalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isEnabled ? palette.textSecondary : palette.textTertiary.opacity(0.5))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hovering && isEnabled ? palette.surfaceElevated.opacity(0.95) : palette.surfaceElevated.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.borderSubtle, lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { hovering = $0 }
    }
}
