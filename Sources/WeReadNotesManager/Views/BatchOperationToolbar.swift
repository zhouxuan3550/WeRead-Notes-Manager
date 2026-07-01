import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// 批量操作工具栏：选中多条笔记后显示。
/// 支持：收藏 / 取消收藏 / 标记复习 / 打标签 / 移书 / 复制 / 导出 / AI 操作 / 删除
struct BatchOperationToolbar: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themePalette) private var palette
    let selectedNotes: [ReadingNote]
    let onClear: () -> Void

    @State private var showTagPicker = false
    @State private var showMovePicker = false
    @State private var showDeleteConfirm = false
    @State private var showAIChoice = false
    @State private var showExportChoice = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // 选中数徽章
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(palette.accent)
                    Text("已选 \(selectedNotes.count) 条")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(palette.accent.opacity(0.18)))

                Divider().frame(height: 16)

                // 收藏 / 取消收藏
                Menu {
                    Button {
                        appVM.batchToggleFavorite(selectedNotes, context: modelContext, favorite: true)
                    } label: { Label("全部收藏", systemImage: "star.fill") }
                    Button {
                        appVM.batchToggleFavorite(selectedNotes, context: modelContext, favorite: false)
                    } label: { Label("取消收藏", systemImage: "star") }
                } label: {
                    Label("收藏", systemImage: "star.fill")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 64)

                // 复习
                Button {
                    appVM.batchMarkReviewed(selectedNotes, context: modelContext)
                    onClear()
                } label: {
                    Label("复习", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)

                // 标签
                Button {
                    showTagPicker = true
                } label: {
                    Label("标签", systemImage: "tag.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)

                // 移书
                if appVM.selectedBook == nil {
                    Button {
                        showMovePicker = true
                    } label: {
                        Label("移到", systemImage: "folder.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                }

                // 复制
                Button {
                    copyAll()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)

                // 导出
                Menu {
                    Button {
                        exportMarkdown()
                    } label: { Label("Markdown", systemImage: "doc.text") }
                    Button {
                        exportJSON()
                    } label: { Label("JSON", systemImage: "curlybraces") }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 68)

                // AI
                Menu {
                    Button {
                        showAIChoice = true
                    } label: { Label("AI 总结", systemImage: "wand.and.stars") }
                } label: {
                    Label("AI", systemImage: "sparkles")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 48)

                Spacer()

                // 取消选择
                Button("取消", action: onClear)
                    .font(.system(size: 12))
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.textSecondary)

                // 删除
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("删除", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .tint(palette.error)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.success)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(palette.surfaceElevated.opacity(0.95))
        .overlay(
            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: 1),
            alignment: .top
        )
        .sheet(isPresented: $showTagPicker) {
            BatchTagPickerSheet(selectedNotes: selectedNotes)
        }
        .sheet(isPresented: $showMovePicker) {
            BatchMoveBookSheet(selectedNotes: selectedNotes)
        }
        .sheet(isPresented: $showAIChoice) {
            BatchAIChoiceSheet(selectedNotes: selectedNotes)
        }
        .confirmationDialog(
            "删除 \(selectedNotes.count) 条笔记？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("移到回收站", role: .destructive) {
                appVM.batchDeleteNotes(selectedNotes, context: modelContext)
                onClear()
            }
            Button("永久删除", role: .destructive) {
                for note in selectedNotes {
                    modelContext.delete(note)
                }
                try? modelContext.save()
                onClear()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("「移到回收站」可在回收站中恢复。永久删除不可恢复。")
        }
    }

    // MARK: - 动作

    private func copyAll() {
        let text = selectedNotes.map { note -> String in
            var s = "> \(note.highlight)"
            if let chapter = note.chapter, !chapter.isEmpty {
                s += " —《\(note.book?.title ?? "")》\(chapter)"
            } else {
                s += " —《\(note.book?.title ?? "")》"
            }
            if let userNote = note.userNote, !userNote.isEmpty {
                s += "\n\n我的想法：\(userNote)"
            }
            return s
        }.joined(separator: "\n\n---\n\n")

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        showStatus("已复制 \(selectedNotes.count) 条到剪贴板")
    }

    private func exportMarkdown() {
        let panel = NSSavePanel()
        if let type = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [type]
        }
        panel.nameFieldStringValue = "批量导出-\(Date().shortString).md"
        if panel.runModal() == .OK, let url = panel.url {
            let md = renderMarkdown()
            try? md.write(to: url, atomically: true, encoding: .utf8)
            showStatus("已导出 Markdown")
        }
    }

    private func exportJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "批量导出-\(Date().shortString).json"
        if panel.runModal() == .OK, let url = panel.url {
            struct ExportItem: Codable {
                let id: String
                let book: String?
                let chapter: String?
                let highlight: String
                let userNote: String?
                let isFavorite: Bool
                let tags: [String]
                let createdAt: Date?
            }
            let items = selectedNotes.map { note in
                ExportItem(
                    id: note.id.uuidString,
                    book: note.book?.title,
                    chapter: note.chapter,
                    highlight: note.highlight,
                    userNote: note.userNote,
                    isFavorite: note.isFavorite,
                    tags: note.tags.map(\.name),
                    createdAt: note.createdAt
                )
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(items) {
                try? data.write(to: url)
                showStatus("已导出 JSON")
            }
        }
    }

    private func renderMarkdown() -> String {
        var md = "# 批量导出 · \(Date().shortString)\n\n"
        md += "共 \(selectedNotes.count) 条笔记\n\n---\n\n"
        for note in selectedNotes {
            md += "## \(note.book?.title ?? "未知书")"
            if let chapter = note.chapter {
                md += " · \(chapter)"
            }
            md += "\n\n"
            md += "> \(note.highlight)\n\n"
            if let userNote = note.userNote, !userNote.isEmpty {
                md += "**想法**：\(userNote)\n\n"
            }
            if !note.tags.isEmpty {
                md += "标签：" + note.tags.map { "`#\($0.name)`" }.joined(separator: " ") + "\n\n"
            }
            md += "---\n\n"
        }
        return md
    }

    private func showStatus(_ text: String) {
        statusMessage = text
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if statusMessage == text {
                    statusMessage = nil
                }
            }
        }
    }
}

// MARK: - 批量 AI 选择

private struct BatchAIChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppViewModel.self) private var appVM
    let selectedNotes: [ReadingNote]

    @State private var isProcessing = false
    @State private var resultText = ""
    @State private var errorMessage: String?

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(palette.accent)
                Text("批量 AI 处理")
                    .font(.headline)
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        aiButton(title: "总结要点", icon: "doc.text.magnifyingglass") {
                            runAI(.summary)
                        }
                        aiButton(title: "提取行动", icon: "checkmark.square") {
                            runAI(.actions)
                        }
                        aiButton(title: "找关联", icon: "link") {
                            runAI(.connections)
                        }
                    }

                    if isProcessing {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("AI 处理中...")
                                .font(.caption)
                        }
                        .padding()
                    }

                    if !resultText.isEmpty {
                        ScrollView {
                            Text(resultText)
                                .font(.system(size: 12))
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 240)
                        .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))

                        HStack {
                            Button {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(resultText, forType: .string)
                            } label: {
                                Label("复制结果", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                // 存为笔记
                                let book: Book
                                if let existing = appVM.books.first {
                                    book = existing
                                } else {
                                    let new = Book(title: "AI 总结")
                                    modelContext.insert(new)
                                    book = new
                                }
                                let note = ReadingNote(
                                    book: book,
                                    chapter: "AI 批量分析",
                                    highlight: String(resultText.prefix(200)),
                                    userNote: resultText,
                                    source: "ai-batch"
                                )
                                modelContext.insert(note)
                                try? modelContext.save()
                                dismiss()
                            } label: {
                                Label("存为笔记", systemImage: "tray.and.arrow.down")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(palette.error)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 560, height: 480)
    }

    private enum AITask { case summary, actions, connections }

    private func aiButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.surface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(palette.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }

    private func runAI(_ task: AITask) {
        guard !selectedNotes.isEmpty else { return }
        guard let apiKey = KeychainService.loadAPIKey(for: .openAI), !apiKey.isEmpty else {
            errorMessage = "请先在设置中配置 OpenAI API Key"
            return
        }

        isProcessing = true
        errorMessage = nil
        resultText = ""

        let context = selectedNotes.prefix(20).map { note -> String in
            var s = "【\((note.book?.title ?? "未知") + (note.chapter.map { " · \($0)" } ?? ""))】\n\(note.highlight)"
            if let u = note.userNote, !u.isEmpty {
                s += "\n想法：\(u)"
            }
            return s
        }.joined(separator: "\n\n")

        let prompt: String
        switch task {
        case .summary:
            prompt = "总结以下笔记的核心要点（3-5 条）：\n\n\(context)"
        case .actions:
            prompt = "从以下笔记里提取可执行行动（5-10 条）：\n\n\(context)"
        case .connections:
            prompt = "找出以下笔记之间的关联、相似观点、矛盾之处：\n\n\(context)"
        }

        let service = AIChatService(provider: .openAI, apiKey: apiKey, model: AIProvider.openAI.defaultModel)

        Task {
            do {
                var collected = ""
                for try await chunk in service.askStream(input: prompt) {
                    collected += chunk
                    await MainActor.run { resultText = collected }
                }
                await MainActor.run { isProcessing = false }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - 原有 sheet（保持兼容）

private struct BatchTagPickerSheet: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var allTags: [Tag]
    let selectedNotes: [ReadingNote]
    @State private var newTagName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("批量打标签")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("新建标签", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                    Button("添加") {
                        guard let tag = appVM.findOrCreateTag(name: newTagName, context: modelContext) else { return }
                        appVM.batchAddTag(tag, to: selectedNotes, context: modelContext)
                        newTagName = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(Tag.normalize(name: newTagName).isEmpty)
                }

                Text("已有标签")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                if allTags.isEmpty {
                    Text("还没有标签")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(allTags) { tag in
                            let alreadyOn = selectedNotes.allSatisfy { $0.tags.contains(where: { $0.id == tag.id }) }
                            Button {
                                if alreadyOn {
                                    appVM.batchRemoveTag(tag, from: selectedNotes, context: modelContext)
                                } else {
                                    appVM.batchAddTag(tag, to: selectedNotes, context: modelContext)
                                }
                            } label: {
                                let color = tag.resolvedColor
                                HStack(spacing: 4) {
                                    Image(systemName: alreadyOn ? "checkmark" : "plus")
                                        .font(.system(size: 9))
                                    Text(tag.name)
                                        .font(.system(size: 12))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(color.opacity(alreadyOn ? 0.35 : 0.15)))
                                .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 480, height: 380)
    }
}

private struct BatchMoveBookSheet: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Book.title) private var allBooks: [Book]
    let selectedNotes: [ReadingNote]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("移到其他书")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()

            List {
                ForEach(allBooks) { book in
                    Button {
                        appVM.batchMoveNotes(selectedNotes, to: book, context: modelContext)
                        dismiss()
                    } label: {
                        HStack {
                            Text(book.title)
                                .font(.system(size: 13))
                            Spacer()
                            Text(book.author ?? "")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 440, height: 420)
    }
}