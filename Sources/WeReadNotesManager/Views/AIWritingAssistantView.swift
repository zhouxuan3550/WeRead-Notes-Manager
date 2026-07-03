import SwiftUI
import SwiftData

// MARK: - AI 写作助手
//
// 基于笔记库，让 AI 生成：
// - 📝 读书札记：把零散划线整理成一篇博客/公众号文章
// - 💡 主题文章：围绕某一主题输出长文
// - 🎯 行动清单：把笔记里的"启发"转化为可执行行动
// - ✍️ 读书卡片：单条笔记的扩展评注
//
// 复用 AIChatService，复用 NoteEmbeddingService 做相关笔记检索。

struct AIWritingAssistantView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext

    @State private var selectedGenre: WritingGenre = .essay
    @State private var topic: String = ""
    @State private var output: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var relatedNotes: [ReadingNote] = []
    @State private var expandedNoteIDs: Set<UUID> = []
    @State private var saveStatus: String?

    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.openAI.rawValue
    @AppStorage("openAIModel") private var openAIModel = AIProvider.openAI.defaultModel
    @AppStorage("deepSeekModel") private var deepSeekModel = AIProvider.deepSeek.defaultModel
    @AppStorage("glmModel") private var glmModel = AIProvider.glm.defaultModel

    @Environment(\.themePalette) private var palette

    enum WritingGenre: String, CaseIterable, Identifiable {
        case essay = "读书札记"
        case article = "主题长文"
        case actions = "行动清单"
        case review = "书评"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .essay: return "doc.text"
            case .article: return "text.book.closed"
            case .actions: return "checkmark.square"
            case .review: return "star.bubble"
            }
        }

        var subtitle: String {
            switch self {
            case .essay: return "把零散划线整理成一篇长文"
            case .article: return "围绕一个主题输出深度文章"
            case .actions: return "把笔记里的启发转化为行动"
            case .review: return "为某本书生成完整书评"
            }
        }
    }

    var body: some View {
        HSplitView {
            // 左侧：配置 + 相关笔记
            configPanel
                .frame(minWidth: 320, idealWidth: 380)

            // 右侧：输出
            outputPanel
                .frame(minWidth: 380)
        }
    }

    // MARK: - 左侧配置

    private var configPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI 写作助手")
                .font(.title2)
                .fontWeight(.semibold)
            Text("基于你的笔记库，让 AI 生成结构化长文")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            // 类型选择
            VStack(alignment: .leading, spacing: 8) {
                Text("文章类型")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(WritingGenre.allCases) { genre in
                        Button {
                            selectedGenre = genre
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: genre.systemImage)
                                    .font(.system(size: 18))
                                Text(genre.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(genre.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundStyle(palette.textTertiary)
                                    .lineLimit(2)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedGenre == genre
                                          ? palette.accent.opacity(0.18)
                                          : palette.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedGenre == genre
                                            ? palette.accent
                                            : palette.borderSubtle,
                                            lineWidth: selectedGenre == genre ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 主题输入
            VStack(alignment: .leading, spacing: 6) {
                Text(topicLabel)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                TextField(topicPlaceholder, text: $topic, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.borderSubtle))
                    .onChange(of: topic) { _, _ in
                        refreshRelatedNotes()
                    }
            }

            // 相关笔记
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("引用笔记")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                    Text("\(relatedNotes.count) 条")
                        .font(.caption)
                        .foregroundStyle(palette.textTertiary)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(relatedNotes.prefix(30)) { note in
                            RelatedNoteRow(
                                note: note,
                                expanded: expandedNoteIDs.contains(note.id),
                                toggle: { toggleExpand(note) }
                            )
                        }
                        if relatedNotes.isEmpty {
                            Text("输入主题后将自动检索相关笔记")
                                .font(.caption)
                                .foregroundStyle(palette.textTertiary)
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }

            // 生成按钮
            Button {
                Task { await generate() }
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(isGenerating ? "生成中..." : "开始生成")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .flatActionButton(.accent, height: 32)
            .controlSize(.large)
            .disabled(isGenerating || topic.isEmpty || relatedNotes.isEmpty)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(palette.error)
            }
        }
        .padding(20)
        .background(palette.surface.opacity(0.3))
    }

    private var topicLabel: String {
        switch selectedGenre {
        case .essay: return "围绕的主题（可选）"
        case .article: return "文章主题"
        case .actions: return "关注的方向"
        case .review: return "书名"
        }
    }

    private var topicPlaceholder: String {
        switch selectedGenre {
        case .essay: return "例如：不确定性"
        case .article: return "例如：成长与自我欺骗"
        case .actions: return "例如：时间管理"
        case .review: return "例如：思考，快与慢"
        }
    }

    // MARK: - 右侧输出

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("生成结果")
                    .font(.headline)
                Spacer()
                if !output.isEmpty {
                    Button {
                        copyToClipboard()
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .flatActionButton(height: 32)
                    .help("复制到剪贴板")

                    Menu {
                        Button {
                            copyAsMarkdown()
                        } label: {
                            Label("复制为 Markdown", systemImage: "doc.richtext")
                        }
                        Button {
                            copyAsHTML()
                        } label: {
                            Label("复制为 HTML", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        Button {
                            shareViaEmail()
                        } label: {
                            Label("发送邮件", systemImage: "envelope")
                        }
                        Button {
                            shareToSocial()
                        } label: {
                            Label("分享到社交", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Label("更多", systemImage: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 32)

                    Button {
                        saveAsNote()
                    } label: {
                        Label("存为笔记", systemImage: "tray.and.arrow.down")
                    }
                    .flatActionButton(.accent, height: 32)

                    Button {
                        exportMarkdown()
                    } label: {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    .flatActionButton(height: 32)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                if output.isEmpty && !isGenerating {
                    ContentUnavailableView(
                        "等待生成",
                        systemImage: "wand.and.stars",
                        description: Text("输入主题，点击「开始生成」")
                    )
                } else {
                    Text(output.isEmpty ? "正在生成..." : output)
                        .font(.system(size: 14))
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(20)
                }
            }

            if let saveStatus {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(palette.success)
                    Text(saveStatus)
                        .font(.caption)
                }
                .padding(12)
            }
        }
    }

    // MARK: - 动作

    private func toggleExpand(_ note: ReadingNote) {
        if expandedNoteIDs.contains(note.id) {
            expandedNoteIDs.remove(note.id)
        } else {
            expandedNoteIDs.insert(note.id)
        }
    }

    private func refreshRelatedNotes() {
        let query = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            relatedNotes = []
            return
        }
        // 先用 embedding 找相关的 10 条
        let allNotes = appVM.allNotes.filter { !$0.isDeleted }
        let retriever = NoteRetriever(notes: allNotes)
        let semanticMatches = retriever.topK(query: query, k: 10).map(\.note)
        // 再补一个关键词匹配
        let lower = query.lowercased()
        let keywordMatches = allNotes.filter { note in
            note.highlight.lowercased().contains(lower)
                || (note.userNote?.lowercased().contains(lower) ?? false)
                || (note.chapter?.lowercased().contains(lower) ?? false)
        }
        // 合并去重
        var seen = Set<UUID>()
        relatedNotes = (semanticMatches + keywordMatches).filter { note in
            if seen.contains(note.id) { return false }
            seen.insert(note.id)
            return true
        }.prefix(30).map { $0 }
    }

    private func generate() async {
        guard !relatedNotes.isEmpty else { return }
        guard let apiKey = KeychainService.loadAPIKey(for: currentProvider), !apiKey.isEmpty else {
            errorMessage = "请先在设置中配置 \(currentProvider.label) API Key"
            return
        }

        errorMessage = nil
        output = ""
        isGenerating = true
        defer { isGenerating = false }

        let context = relatedNotes.prefix(20).map { note -> String in
            var line = "【\((note.book?.title ?? "未知") + (note.chapter.map { " · \($0)" } ?? ""))】\n\(note.highlight)"
            if let u = note.userNote, !u.isEmpty {
                line += "\n我的想法：\(u)"
            }
            return line
        }.joined(separator: "\n\n")

        let prompt = buildPrompt(notes: context)

        let service = AIChatService(
            provider: currentProvider,
            apiKey: apiKey,
            model: currentModel
        )

        do {
            var collected = ""
            for try await chunk in service.askStream(input: prompt) {
                collected += chunk
                output = collected
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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

    private func buildPrompt(notes: String) -> String {
        switch selectedGenre {
        case .essay:
            return """
            基于以下用户笔记，写一篇 800-1200 字的读书札记。
            主题：\(topic)

            要求：
            - 开篇用一个具体场景或反问引入
            - 中段 3-5 个段落，每段一个核心观点
            - 引用具体笔记内容（标注 [笔记 N]）
            - 结尾呼应开头，给出开放式思考
            - 文风自然、有个人视角，不要 AI 套话

            笔记：
            \(notes)
            """
        case .article:
            return """
            围绕「\(topic)」写一篇 1500-2500 字的深度文章。
            用用户笔记里的素材作为论据。

            要求：
            - 大标题 + 副标题
            - 引言 / 主体（3-5 节，每节有小标题） / 结论
            - 每节要有具体论据，引用笔记（标注 [笔记 N]）
            - 加入你自己的判断和延伸思考
            - 避免空洞总结，多用具体场景和反直觉观点

            笔记：
            \(notes)
            """
        case .actions:
            return """
            从以下笔记里提取"可执行行动清单"。
            关注方向：\(topic)

            要求：
            - 输出 8-15 条具体行动，每条一句话
            - 行动必须可立即开始（不是"多读书"这种空话）
            - 按优先级分组：立刻 / 本周 / 长期
            - 标注触发该行动的笔记编号

            笔记：
            \(notes)
            """
        case .review:
            return """
            为《\(topic)》写一篇 1000-1500 字的书评。

            要求：
            - 这本书讲了什么（用 3 段说清楚）
            - 最值得读的 3 个观点
            - 这本书的局限是什么
            - 推荐给谁、不推荐给谁
            - 用"普通读者"口吻，不要营销腔

            用户笔记（来自该书）：
            \(notes)
            """
        }
    }

    private func copyToClipboard() {
        #if canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(output, forType: .string)
        saveStatus = "已复制到剪贴板"
        #endif
    }

    private func saveAsNote() {
        let book = appVM.books.first ?? Book(title: "AI 写作")
        modelContext.insert(book)
        let note = ReadingNote(
            book: book,
            chapter: "AI 生成 · \(selectedGenre.rawValue)",
            highlight: String(output.prefix(200)),
            userNote: output,
            source: "ai-writing"
        )
        modelContext.insert(note)
        do {
            try modelContext.save()
            saveStatus = "已存为笔记"
        } catch {
            saveStatus = "保存失败：\(error.localizedDescription)"
        }
    }

    private func exportMarkdown() {
        #if canImport(AppKit)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .text]
        panel.nameFieldStringValue = "AI-写作-\(Date().shortString).md"
        if panel.runModal() == .OK, let url = panel.url {
            try? output.write(to: url, atomically: true, encoding: .utf8)
            saveStatus = "已导出到 \(url.lastPathComponent)"
        }
        #endif
    }

    private func copyAsMarkdown() {
        #if canImport(AppKit)
        let md = renderAsMarkdown()
        let pb = NSPasteboard.general
        pb.clearContents()
        // 同时设置纯文本和 markdown 类型
        pb.setString(md, forType: .string)
        if #available(macOS 11.0, *) {
            pb.setString(md, forType: .init("public.markdown"))
        }
        saveStatus = "已复制为 Markdown"
        #endif
    }

    private func copyAsHTML() {
        #if canImport(AppKit)
        let html = renderAsHTML()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(html, forType: .html)
        pb.setString(stripMarkdown(output), forType: .string)
        saveStatus = "已复制为 HTML"
        #endif
    }

    private func shareViaEmail() {
        #if canImport(AppKit)
        let subject = "【书摘温故】\(selectedGenre.rawValue) · \(topic)"
        let body = renderAsMarkdown()
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") else { return }
        NSWorkspace.shared.open(url)
        saveStatus = "已唤起邮件客户端"
        #endif
    }

    private func shareToSocial() {
        #if canImport(AppKit)
        let summary = String(output.prefix(200))
        let twitterURL = "https://twitter.com/intent/tweet?text=\(summary.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        let weiboURL = "https://service.weibo.com/share/share.php?title=\(summary.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        let panel = NSAlert()
        panel.messageText = "分享到社交平台"
        panel.informativeText = "选择平台"
        panel.addButton(withTitle: "𝕏 (Twitter)")
        panel.addButton(withTitle: "微博")
        panel.addButton(withTitle: "取消")

        let response = panel.runModal()
        let urlString: String?
        switch response {
        case .alertFirstButtonReturn: urlString = twitterURL
        case .alertSecondButtonReturn: urlString = weiboURL
        default: urlString = nil
        }
        if let str = urlString, let url = URL(string: str) {
            NSWorkspace.shared.open(url)
            saveStatus = "已打开分享页面"
        }
        #endif
    }

    // MARK: - 渲染辅助

    private func renderAsMarkdown() -> String {
        let date = Date().shortString
        var md = "# \(selectedGenre.rawValue) · \(topic)\n\n"
        md += "_生成于 \(date) · 书摘温故_\n\n"
        md += "---\n\n"
        md += output
        md += "\n\n---\n\n"
        md += "## 参考笔记\n\n"
        for (i, note) in relatedNotes.prefix(10).enumerated() {
            let book = note.book?.title ?? "未知"
            md += "[\(i + 1)] 《\(book)》\(note.chapter.map { " · \($0)" } ?? "")\n"
            md += "> \(note.highlight)\n\n"
        }
        return md
    }

    private func renderAsHTML() -> String {
        let escaped = output
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br/>")
        return """
        <html><body style="font-family: -apple-system, sans-serif; line-height: 1.7; padding: 24px;">
        <h1>\(selectedGenre.rawValue) · \(topic)</h1>
        <p><em>生成于书摘温故</em></p>
        <hr/>
        <p>\(escaped)</p>
        </body></html>
        """
    }

    private func stripMarkdown(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "> ", with: "")
    }
}

// MARK: - 相关笔记行

struct RelatedNoteRow: View {
    let note: ReadingNote
    let expanded: Bool
    let toggle: () -> Void

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: toggle) {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.book?.title ?? "未知书")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                        Text(note.highlight)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(expanded ? 6 : 1)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(palette.surface.opacity(0.5))
        )
    }
}
