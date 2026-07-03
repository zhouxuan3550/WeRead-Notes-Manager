import SwiftUI
import SwiftData

/// AI 整本书总结视图（结构化 JSON 版）。
struct BookSummaryView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themePalette) private var palette
    @Bindable var book: Book

    @State private var summary: StructuredBookSummary?
    @State private var isGenerating = false
    @State private var statusMessage: String?
    @State private var existingSummary: BookSummary?

    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.openAI.rawValue
    @AppStorage("openAIModel") private var openAIModel = AIProvider.openAI.defaultModel
    @AppStorage("deepSeekModel") private var deepSeekModel = AIProvider.deepSeek.defaultModel
    @AppStorage("glmModel") private var glmModel = AIProvider.glm.defaultModel

    private var provider: AIProvider { AIProvider(rawValue: aiProviderRaw) ?? .openAI }
    private var model: String {
        switch provider {
        case .openAI: return openAIModel
        case .deepSeek: return deepSeekModel
        case .glm: return glmModel
        case .minimax, .aliyun, .doubao: return provider.savedModel
        }
    }
    private var apiKey: String { KeychainService.loadAPIKey(for: provider) ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                if let summary {
                    structuredContent(summary)
                        .padding(24)
                } else if isGenerating {
                    loadingView
                } else {
                    emptyView
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 620, minHeight: 600)
        .onAppear {
            existingSummary = appVM.findSummary(for: book, context: modelContext)
            if let existing = existingSummary,
               let data = existing.content.data(using: .utf8),
               let parsed = try? JSONDecoder().decode(StructuredBookSummary.self, from: data) {
                summary = parsed
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 总结 · 《\(book.title)》")
                    .font(.system(size: 16, weight: .semibold))
                Text("基于你的 \(book.notes.filter { !$0.isDeleted }.count) 条笔记")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $aiProviderRaw) {
                ForEach(AIProvider.allCases) { p in
                    Text(p.label).tag(p.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 120)

            Button {
                Task { await generate() }
            } label: {
                Label(isGenerating ? "生成中..." : "生成总结", systemImage: "sparkles")
            }
            .flatActionButton(.accent, height: 32)
            .disabled(isGenerating || apiKey.isEmpty || book.notes.isEmpty)

            Button {
                saveAndDismiss()
            } label: {
                Text("保存并关闭")
            }
            .flatActionButton(height: 32)
            .disabled(summary == nil)
        }
        .padding(20)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在生成结构化总结...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "暂无总结",
            systemImage: "sparkles",
            description: Text("点击上方按钮生成结构化总结")
        )
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func structuredContent(_ summary: StructuredBookSummary) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            summarySection("核心思想", icon: "lightbulb") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(summary.coreIdeas, id: \.self) { idea in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(palette.accent)
                            Text(idea)
                                .font(.system(size: 14))
                                .lineSpacing(4)
                        }
                    }
                }
            }

            summarySection("关键主题", icon: "bookmark") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(summary.themes, id: \.name) { theme in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(theme.name)
                                .font(.system(size: 15, weight: .semibold))
                            ForEach(theme.notes, id: \.self) { note in
                                Text("> \(note)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(palette.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(palette.borderSubtle, lineWidth: 0.5)
                        )
                    }
                }
            }

            summarySection("思考脉络", icon: "brain.head.profile") {
                Text(summary.thinkingThread)
                    .font(.system(size: 14))
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            summarySection("金句", icon: "quote.opening") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(summary.quotes, id: \.self) { quote in
                        Text("“\(quote)”")
                            .font(.system(size: 15, design: .serif))
                            .lineSpacing(4)
                            .padding(.leading, 12)
                    }
                }
            }

            summarySection("行动启发", icon: "checklist") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(summary.actionItems, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.success)
                            Text(item)
                                .font(.system(size: 14))
                                .lineSpacing(4)
                        }
                    }
                }
            }
        }
    }

    private func summarySection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func generate() async {
        guard !apiKey.isEmpty else {
            statusMessage = "请先在「设置」中配置 \(provider.label) 的 API Key。"
            return
        }
        isGenerating = true
        statusMessage = "正在生成..."
        summary = nil

        let context = buildContext()
        let service = AIChatService(provider: provider, apiKey: apiKey, model: model)
        let cache = AIResultCache(context: modelContext)
        let quota = AIQuotaTracker()
        let runner = AITaskRunner(service: service, cache: cache, quota: quota)

        do {
            let input = BookSummaryInput(title: book.title, author: book.author, context: context)
            summary = try await runner.run(BookSummaryTask(), input: input)
            statusMessage = "已完成。"
            isGenerating = false
        } catch {
            statusMessage = error.localizedDescription
            isGenerating = false
        }
    }

    private func buildContext() -> String {
        let liveNotes = book.notes.filter { !$0.isDeleted }
        let byChapter = Dictionary(grouping: liveNotes) { $0.chapter ?? "未分章" }
        var sections: [String] = []
        for (chapter, notes) in byChapter.sorted(by: { $0.key < $1.key }) {
            var section = "## \(chapter)\n"
            for note in notes {
                section += "> \(note.highlight)\n"
                if let userNote = note.userNote, !userNote.isEmpty {
                    section += "我的想法：\(userNote)\n"
                }
                section += "\n"
            }
            sections.append(section)
        }
        return sections.joined(separator: "\n")
    }

    private func saveAndDismiss() {
        guard let summary,
              let data = try? JSONEncoder().encode(summary),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        appVM.upsertSummary(for: book, content: jsonString, context: modelContext)
        dismiss()
    }
}
