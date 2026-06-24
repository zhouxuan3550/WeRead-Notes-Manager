import SwiftUI
import SwiftData

/// AI 整本书总结视图（Feature 9）。
struct BookSummaryView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var book: Book

    @State private var summaryContent: String = ""
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
        }
    }
    private var apiKey: String { KeychainService.loadAPIKey(for: provider) ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if summaryContent.isEmpty && existingSummary == nil && !isGenerating {
                        ContentUnavailableView(
                            "暂无总结",
                            systemImage: "sparkles",
                            description: Text("点击下方按钮，让 AI 基于你的划线和想法整理结构化总结。")
                        )
                    } else {
                        Text(summaryContent.isEmpty ? existingSummary?.content ?? "" : summaryContent)
                            .font(.system(size: 14))
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 60)
                    }
                }
                .padding(24)
            }

            if isGenerating {
                ProgressView()
                    .controlSize(.small)
                    .padding(.vertical, 8)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
        }
        .frame(minWidth: 540, minHeight: 560)
        .onAppear {
            existingSummary = appVM.findSummary(for: book, context: modelContext)
            if let existing = existingSummary {
                summaryContent = existing.content
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
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating || apiKey.isEmpty || book.notes.isEmpty)

            Button {
                saveAndDismiss()
            } label: {
                Text("保存并关闭")
            }
            .buttonStyle(.bordered)
            .disabled(summaryContent.isEmpty)
        }
        .padding(20)
    }

    private func generate() async {
        guard !apiKey.isEmpty else {
            statusMessage = "请先在「设置」中配置 \(provider.label) 的 API Key。"
            return
        }
        isGenerating = true
        statusMessage = "正在生成..."
        summaryContent = ""

        let context = buildContext()
        let service = AIChatService(provider: provider, apiKey: apiKey, model: model)

        do {
            for try await delta in service.summarizeBook(
                title: book.title,
                author: book.author,
                context: context
            ) {
                summaryContent += delta
            }
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
        appVM.upsertSummary(for: book, content: summaryContent, context: modelContext)
        dismiss()
    }
}