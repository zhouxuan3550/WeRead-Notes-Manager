import SwiftUI
import SwiftData
import AppKit

/// AI 助手视图 - 提供实用的笔记处理功能，跨书问答基于 RAG 检索。
struct CrossNoteAskView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themePalette) private var palette
    @Query(sort: \Book.updatedAt, order: .reverse) private var allBooks: [Book]

    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.openAI.rawValue
    @AppStorage("openAIModel") private var openAIModel = AIProvider.openAI.defaultModel
    @AppStorage("deepSeekModel") private var deepSeekModel = AIProvider.deepSeek.defaultModel
    @AppStorage("glmModel") private var glmModel = AIProvider.glm.defaultModel

    @State private var selectedBook: Book?
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var isProcessing = false
    @State private var resultText = ""
    @State private var errorMessage: String?
    @State private var citations: [Citation] = []
    @State private var question = ""

    enum QuickAction {
        case summarize
        case extractKeyPoints
        case generateTags
        case translate
        case rewrite
        case createFlashcards
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                noteSelectionPanel
                    .frame(width: 320)

                Divider()

                aiProcessingPanel
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI 助手")
                    .font(.system(size: 20, weight: .semibold))
                Text("选择笔记，让 AI 帮你处理；或直接跨书提问")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("处理中...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var noteSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("选择书籍")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Picker("", selection: Binding(
                    get: { selectedBook },
                    set: { selectedBook = $0; selectedNoteIDs.removeAll() }
                )) {
                    Text("全部书籍").tag(Book?.none)
                    if !allBooks.isEmpty {
                        Divider()
                        ForEach(allBooks) { book in
                            Text(book.title).tag(book as Book?)
                        }
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
            }

            Divider().padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("选择笔记 (\(selectedNoteIDs.count))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !selectedNoteIDs.isEmpty {
                        Button("清空") {
                            selectedNoteIDs.removeAll()
                        }
                        .flatActionButton(height: 32)
                        .controlSize(.mini)
                    }
                }
                .padding(.horizontal, 16)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(availableNotes) { note in
                            NoteSelectionRow(
                                note: note,
                                isSelected: selectedNoteIDs.contains(note.id)
                            ) {
                                if selectedNoteIDs.contains(note.id) {
                                    selectedNoteIDs.remove(note.id)
                                } else {
                                    selectedNoteIDs.insert(note.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            Divider().padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("快捷选择")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("全部") {
                        selectedNoteIDs = Set(availableNotes.map { $0.id })
                    }
                    Button("收藏") {
                        selectedNoteIDs = Set(availableNotes.filter { $0.isFavorite }.map { $0.id })
                    }
                    Button("未复习") {
                        selectedNoteIDs = Set(availableNotes.filter { !$0.isReviewed }.map { $0.id })
                    }
                }
                .flatActionButton(height: 32)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(palette.surface.opacity(0.30))
    }

    private var aiProcessingPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("快捷功能")
                    .font(.system(size: 13, weight: .semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    QuickActionButton(
                        title: "总结笔记",
                        subtitle: "提炼核心内容",
                        icon: "doc.text.magnifyingglass"
                    ) { performAction(.summarize) }

                    QuickActionButton(
                        title: "提取要点",
                        subtitle: "关键信息",
                        icon: "list.bullet"
                    ) { performAction(.extractKeyPoints) }

                    QuickActionButton(
                        title: "生成标签",
                        subtitle: "AI 推荐标签",
                        icon: "tag"
                    ) { performAction(.generateTags) }

                    QuickActionButton(
                        title: "翻译内容",
                        subtitle: "中英文互译",
                        icon: "globe"
                    ) { performAction(.translate) }

                    QuickActionButton(
                        title: "润色改写",
                        subtitle: "优化表达",
                        icon: "wand.and.stars"
                    ) { performAction(.rewrite) }

                    QuickActionButton(
                        title: "制作闪卡",
                        subtitle: "Anki 格式",
                        icon: "rectangle.on.rectangle"
                    ) { performAction(.createFlashcards) }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            Divider()

            // 跨书问答
            VStack(alignment: .leading, spacing: 10) {
                Text("跨书问答（RAG）")
                    .font(.system(size: 13, weight: .semibold))

                TextEditor(text: $question)
                    .font(.system(size: 13))
                    .frame(minHeight: 70)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .appFieldSurface()

                HStack {
                    Text("基于已选笔记语义检索最相关片段作答")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await askWithRAG() }
                    } label: {
                        Label(isProcessing ? "思考中..." : "提问", systemImage: "paperplane")
                    }
                    .flatActionButton(.accent, height: 32)
                    .disabled(isProcessing || cleanedAPIKey.isEmpty || question.trimmingCharacters(in: .whitespaces).isEmpty || selectedNoteIDs.isEmpty)
                }
            }
            .padding(.horizontal, 16)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("结果")
                    .font(.system(size: 13, weight: .semibold))

                if let errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                ScrollView {
                    if resultText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)
                            Text("选择笔记后使用快捷功能或直接提问")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        Text(resultText)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
                .appFieldSurface(cornerRadius: DesignSystem.CornerRadius.lg)

                if !citations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("引用片段")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach(citations) { citation in
                            Button {
                                jumpTo(citation: citation)
                            } label: {
                                HStack(spacing: 8) {
                                    Text("[片段 \(citation.index)]")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                    Text(citation.preview)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(8)
                                .appOptionSurface()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !resultText.isEmpty {
                    HStack(spacing: 8) {
                        Spacer()
                        Button("复制") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(resultText, forType: .string)
                        }
                        .flatActionButton(height: 32)

                        Button("清空") {
                            resultText = ""
                            citations = []
                        }
                        .flatActionButton(height: 32)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var availableNotes: [ReadingNote] {
        let notes: [ReadingNote]
        if let book = selectedBook {
            notes = book.notes.filter { !$0.isDeleted }
        } else {
            notes = appVM.allNotes
        }
        return notes.filter { !$0.isDeleted }
    }

    private var cleanedAPIKey: String {
        KeychainService.loadAPIKey(for: currentProvider) ?? ""
    }

    private var currentProvider: AIProvider {
        AIProvider(rawValue: aiProviderRaw) ?? .openAI
    }

    private var currentModel: String {
        switch currentProvider {
        case .openAI: return openAIModel
        case .deepSeek: return deepSeekModel
        case .glm: return glmModel
        case .minimax, .aliyun, .doubao: return currentProvider.savedModel
        }
    }

    private var selectedNotes: [ReadingNote] {
        availableNotes.filter { selectedNoteIDs.contains($0.id) }
    }

    private func performAction(_ action: QuickAction) {
        guard !selectedNoteIDs.isEmpty else {
            errorMessage = "请先选择笔记"
            return
        }

        guard !cleanedAPIKey.isEmpty else {
            errorMessage = "请先在设置中配置 AI API Key"
            return
        }

        isProcessing = true
        errorMessage = nil
        resultText = ""
        citations = []

        Task {
            await runAction(action)
        }
    }

    private func runAction(_ action: QuickAction) async {
        let notesArray = Array(selectedNotes)
        let service = AIChatService(provider: currentProvider, apiKey: cleanedAPIKey, model: currentModel)

        do {
            let prompt = buildPrompt(for: action, notes: notesArray)
            var text = ""
            for try await delta in service.askStream(input: prompt) {
                text += delta
            }
            await MainActor.run {
                resultText = text
                citations = []
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    private func askWithRAG() async {
        guard !cleanedAPIKey.isEmpty else {
            errorMessage = "请先在设置中配置 AI API Key"
            return
        }
        guard !selectedNotes.isEmpty else {
            errorMessage = "请先选择笔记"
            return
        }

        isProcessing = true
        errorMessage = nil
        resultText = ""
        citations = []

        let notesArray = Array(selectedNotes)
        let retriever = NoteRetriever(notes: notesArray)
        let context = retriever.contextString(for: question, k: 8)

        // 构建引用映射
        let top = retriever.topK(query: question, k: 8)
        var citationMap: [Int: ReadingNote] = [:]
        for (index, pair) in top.enumerated() {
            citationMap[index + 1] = pair.note
        }

        let service = AIChatService(provider: currentProvider, apiKey: cleanedAPIKey, model: currentModel)

        do {
            var text = ""
            for try await delta in service.askWithContext(question: question, context: context) {
                text += delta
            }

            let parsedCitations = extractCitations(from: text, noteMap: citationMap)

            await MainActor.run {
                resultText = text
                citations = parsedCitations
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    private func extractCitations(from text: String, noteMap: [Int: ReadingNote]) -> [Citation] {
        let pattern = #"\[片段\s*(\d+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        var seen: Set<Int> = []
        var result: [Citation] = []
        for match in matches {
            guard let numberRange = Range(match.range(at: 1), in: text) else { continue }
            guard let index = Int(text[numberRange]) else { continue }
            guard !seen.contains(index), let note = noteMap[index] else { continue }
            seen.insert(index)
            let preview = String(note.highlight.prefix(60))
            result.append(Citation(index: index, noteID: note.id, preview: preview, note: note))
        }
        return result
    }

    private func buildPrompt(for action: QuickAction, notes: [ReadingNote]) -> String {
        let notesText = notes.map { note in
            var text = note.highlight
            if let userNote = note.userNote, !userNote.isEmpty {
                text += "\n\n我的想法：\(userNote)"
            }
            return text
        }.joined(separator: "\n\n---\n\n")

        switch action {
        case .summarize:
            return "请总结以下笔记内容，提炼核心观点：\n\n\(notesText)"
        case .extractKeyPoints:
            return "请提取以下笔记中的关键要点，用清晰的列表呈现：\n\n\(notesText)"
        case .generateTags:
            return "请为以下笔记推荐 3-5 个合适的标签，用中文：\n\n\(notesText)"
        case .translate:
            return "请将以下内容翻译为中文（如果是中文则翻译为英文）：\n\n\(notesText)"
        case .rewrite:
            return "请润色和改写以下内容，让它更清晰流畅：\n\n\(notesText)"
        case .createFlashcards:
            return "请将以下内容制作成 Anki 闪卡格式（正面问题，背面答案）：\n\n\(notesText)"
        }
    }

    private func jumpTo(citation: Citation) {
        let note = citation.note
        appVM.selectedBook = note.book
        appVM.selectedNote = note
        appVM.selectedSidebarItem = .books
    }
}

// MARK: - 引用

struct Citation: Identifiable {
    let id = UUID()
    let index: Int
    let noteID: UUID
    let preview: String
    let note: ReadingNote
}

private struct NoteSelectionRow: View {
    let note: ReadingNote
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(note.highlight)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                    Text(note.book?.title ?? "未知书籍")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appOptionSurface(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .flatActionButton(.secondary, height: 54)
    }
}
