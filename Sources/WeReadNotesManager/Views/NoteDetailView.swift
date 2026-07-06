import AppKit
import SwiftUI

struct NoteDetailView: View {
    let note: ReadingNote
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themePalette) private var palette
    @State private var isEditing = false
    @State private var editHighlight = ""
    @State private var editUserNote = ""
    @State private var editChapter = ""
    @State private var editLocation = ""
    @State private var exportError: String?
    @State private var statusMessage: String?
    @State private var cardTemplate: ReadingCardTemplate = .dark
    @State private var showAskAI = false
    @State private var showExportOptions = false
    @State private var showWritingCard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                navigationBar
                header
                Divider()
                highlightSection
                if let userNote = note.userNote, !userNote.isEmpty {
                    userNoteSection(userNote)
                }
                metadataSection
                actionButtons
                noteStepper
            }
            .padding(24)
        }
        .sheet(isPresented: $isEditing) {
            editSheet
        }
        .sheet(isPresented: $showAskAI) {
            AskAIView(note: note)
        }
        .sheet(isPresented: $showWritingCard) {
            WritingCardGeneratorView(note: note)
        }
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("好") {}
        } message: {
            Text(exportError ?? "")
        }
        .overlay(alignment: .bottom) {
            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(palette.surfaceElevated)
                            .overlay(Capsule().stroke(palette.borderMedium, lineWidth: 0.5))
                    )
                    .padding(.bottom, 20)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Sharing helpers (Feature 8)

    private func renderShareText() -> String {
        let bookTitle = note.book?.title ?? "未知书籍"
        let author = note.book?.author.map { " · \($0)" } ?? ""
        var text = "> \(note.highlight)\n>\n> ——《\(bookTitle)》\(author)"
        if let userNote = note.userNote, !userNote.isEmpty {
            text += "\n\n我的想法：\(userNote)"
        }
        return text
    }

    private func renderMarkdownQuote() -> String {
        let bookTitle = note.book?.title ?? "未知书籍"
        let author = note.book?.author.map { "_\($0)_" } ?? ""
        var md = "> \(note.highlight)\n>\n> ——《\(bookTitle)》\(author)"
        if let userNote = note.userNote, !userNote.isEmpty {
            md += "\n\n**我的想法**：\(userNote)"
        }
        return md
    }

    private var navigationBar: some View {
        HStack(spacing: 10) {
            Button {
                returnToBook()
            } label: {
                Label("返回本书", systemImage: "chevron.left")
            }
            .flatActionButton(height: 32)
            .keyboardShortcut("[", modifiers: [.command])

            if let positionText {
                Text(positionText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(palette.surfaceElevated)
                            .overlay(Capsule().stroke(palette.borderSubtle, lineWidth: 0.5))
                    )
            }

            Spacer()

            Button {
                goToPreviousNote()
            } label: {
                Label("上一条", systemImage: "chevron.up")
            }
            .flatActionButton(height: 32)
            .disabled(previousNote == nil)
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button {
                goToNextNote()
            } label: {
                Label("下一条", systemImage: "chevron.down")
            }
            .flatActionButton(height: 32)
            .disabled(nextNote == nil)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let bookTitle = note.book?.title {
                Text(bookTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
            }
            HStack(spacing: 8) {
                if let author = note.book?.author {
                    Text(author)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.textSecondary)
                }
                if let chapter = note.chapter {
                    Text("· \(chapter)")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
    }

    private var highlightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("原文划线")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Text(note.highlight)
                .font(.system(size: 16))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(palette.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.borderSubtle, lineWidth: 1)
                )
        }
    }

    private func userNoteSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("我的想法")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.borderSubtle, lineWidth: 1)
                )
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let location = note.location, !location.isEmpty {
                metaRow("位置", location)
            }
            if let createdAt = note.createdAt {
                metaRow("创建时间", createdAt.shortString)
            }
            metaRow("导入时间", note.importedAt.shortString)
            metaRow("复习次数", "\(note.reviewCount) 次")
            if let lastReviewed = note.lastReviewedAt {
                metaRow("上次复习", lastReviewed.shortString)
            }
            metaRow("收藏", note.isFavorite ? "是" : "否")
            metaRow("已复习", note.isReviewed ? "是" : "否")

            Divider().padding(.vertical, 4)

            TagChipEditor(note: note)
        }
        .padding(.top, 8)
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(palette.textPrimary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // MARK: 一级操作
            Button {
                appVM.toggleFavorite(note)
            } label: {
                Label(note.isFavorite ? "已收藏" : "收藏", systemImage: note.isFavorite ? "star.fill" : "star")
            }
            .flatActionButton(note.isFavorite ? .accent : .secondary, height: 32)

            Button {
                appVM.markReviewed(note)
            } label: {
                Label("已复习", systemImage: "checkmark.circle.fill")
            }
            .flatActionButton(.secondary, height: 32)

            Button {
                showAskAI = true
            } label: {
                Label("问 AI", systemImage: "sparkles")
            }
            .flatActionButton(.accent, height: 32)

            Spacer()

            // MARK: 导出与分享
            HStack(spacing: 8) {
                Picker("模板", selection: $cardTemplate) {
                    ForEach(ReadingCardTemplate.allCases) { template in
                        Text(template.label).tag(template)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 80)

                Button {
                    do {
                        try ReadingCardExporter.export(note: note, template: cardTemplate)
                    } catch {
                        exportError = error.localizedDescription
                    }
                } label: {
                    Label("卡片", systemImage: "photo")
                }
                .flatActionButton(.secondary, height: 32)

                Menu {
                    if let sourceURL = note.sourceURL, let url = URL(string: sourceURL) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("打开微信读书", systemImage: "arrow.up.forward.app")
                        }
                    }

                    Button {
                        showWritingCard = true
                    } label: {
                        Label("生成素材卡", systemImage: "rectangle.stack")
                    }

                    Button {
                        exportToAnki()
                    } label: {
                        Label("导出 Anki", systemImage: "rectangle.on.rectangle")
                    }

                    Button {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(renderMarkdownQuote(), forType: .string)
                        statusMessage = "已复制 Markdown 引用"
                    } label: {
                        Label("复制 Markdown 引用", systemImage: "doc.on.doc")
                    }

                    ShareLink(
                        item: renderShareText(),
                        subject: Text(note.book?.title ?? "书摘"),
                        message: Text(note.highlight),
                        preview: SharePreview(
                            note.book?.title ?? "书摘",
                            image: Image(systemName: "book")
                        )
                    ) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .flatActionButton(.secondary, height: 32)
            }

            // MARK: 笔记管理
            Button {
                startEditing()
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .flatActionButton(.secondary, height: 32)

            Button(role: .destructive) {
                appVM.deleteNote(note, context: modelContext)
            } label: {
                Label("删除", systemImage: "trash")
            }
            .flatActionButton(.destructive, height: 32)
        }
        .padding(.top, 12)
    }

    private var noteStepper: some View {
        HStack(spacing: 12) {
            Button {
                goToPreviousNote()
            } label: {
                Label(previousNoteLabel, systemImage: "arrow.up")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .flatActionButton(height: 32)
            .controlSize(.large)
            .disabled(previousNote == nil)

            Button {
                goToNextNote()
            } label: {
                Label(nextNoteLabel, systemImage: "arrow.down")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .flatActionButton(height: 32)
            .controlSize(.large)
            .disabled(nextNote == nil)
        }
        .padding(.top, 4)
    }

    private func startEditing() {
        editHighlight = note.highlight
        editUserNote = note.userNote ?? ""
        editChapter = note.chapter ?? ""
        editLocation = note.location ?? ""
        isEditing = true
    }

    private var orderedNotes: [ReadingNote] {
        guard let book = note.book else {
            return []
        }
        return book.notes.sorted {
            let left = "\($0.chapter ?? "未分章")|\($0.location ?? "")|\($0.createdAt?.timeIntervalSince1970 ?? 0)"
            let right = "\($1.chapter ?? "未分章")|\($1.location ?? "")|\($1.createdAt?.timeIntervalSince1970 ?? 0)"
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }

    private var currentIndex: Int? {
        orderedNotes.firstIndex { $0.id == note.id }
    }

    private var previousNote: ReadingNote? {
        guard let currentIndex, currentIndex > 0 else {
            return nil
        }
        return orderedNotes[currentIndex - 1]
    }

    private var nextNote: ReadingNote? {
        guard let currentIndex, currentIndex + 1 < orderedNotes.count else {
            return nil
        }
        return orderedNotes[currentIndex + 1]
    }

    private var positionText: String? {
        guard let currentIndex else {
            return nil
        }
        return "第 \(currentIndex + 1) / \(orderedNotes.count) 条"
    }

    private var previousNoteLabel: String {
        guard let previousNote else {
            return "已经是第一条"
        }
        return "上一条：\(shortTitle(for: previousNote))"
    }

    private var nextNoteLabel: String {
        guard let nextNote else {
            return "已经是最后一条"
        }
        return "下一条：\(shortTitle(for: nextNote))"
    }

    private func shortTitle(for note: ReadingNote) -> String {
        let text = note.highlight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 22 else {
            return text
        }
        return String(text.prefix(22)) + "..."
    }

    private func returnToBook() {
        if let book = note.book {
            appVM.selectedBook = book
            appVM.selectedSidebarItem = .books
        }
        appVM.selectedNote = nil
    }

    private func goToPreviousNote() {
        guard let previousNote else {
            return
        }
        appVM.selectedBook = previousNote.book
        appVM.selectedNote = previousNote
    }

    private func goToNextNote() {
        guard let nextNote else {
            return
        }
        appVM.selectedBook = nextNote.book
        appVM.selectedNote = nextNote
    }

    private var editSheet: some View {
        VStack(spacing: 16) {
            Text("编辑笔记")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
            TextField("章节", text: $editChapter)
                .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: 4) {
                Text("划线内容")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                ThemedTextEditor(text: $editHighlight, minHeight: 80)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("我的想法")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                ThemedTextEditor(text: $editUserNote, minHeight: 60)
            }
            TextField("位置 / 页码", text: $editLocation)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { isEditing = false }
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Button("保存") {
                    note.highlight = editHighlight.trimmingCharacters(in: .whitespaces)
                    let un = editUserNote.trimmingCharacters(in: .whitespaces)
                    note.userNote = un.isEmpty ? nil : un
                    let ch = editChapter.trimmingCharacters(in: .whitespaces)
                    note.chapter = ch.isEmpty ? nil : ch
                    let loc = editLocation.trimmingCharacters(in: .whitespaces)
                    note.location = loc.isEmpty ? nil : loc
                    note.updatedAt = Date()
                    isEditing = false
                }
                .flatActionButton(.accent, height: 32)
                .disabled(editHighlight.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440, height: 420)
        .background(palette.background)
    }

    private struct ThemedTextEditor: View {
        @Binding var text: String
        var minHeight: CGFloat
        @Environment(\.themePalette) private var palette

        var body: some View {
            TextEditor(text: $text)
                .font(.system(size: 14))
                .foregroundStyle(palette.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(4)
                .background(palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(palette.borderMedium, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Anki 导出
    
    private func exportToAnki() {
        let csv = AnkiExporter.exportToCSV(notes: [note])
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "weread-note-\(note.id.uuidString.prefix(8)).txt"
        panel.prompt = "导出"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                statusMessage = "已导出 Anki 卡片"
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
}
