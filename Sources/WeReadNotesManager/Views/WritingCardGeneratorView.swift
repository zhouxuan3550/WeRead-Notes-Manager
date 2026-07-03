import SwiftUI
import SwiftData

/// 单条笔记生成写作素材卡的弹窗。
struct WritingCardGeneratorView: View {
    let note: ReadingNote
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themePalette) private var palette

    @State private var output: WritingCardOutput?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 560, minHeight: 520)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("生成写作素材卡")
                    .font(.system(size: 18, weight: .semibold))
                Text(note.book?.title ?? "当前书摘")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var content: some View {
        VStack(spacing: 16) {
            if isGenerating {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在扩展书摘为写作素材...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if let output {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        cardSection("核心观点", output.coreIdea)
                        cardSection("适用场景", output.scenarios.map { "· \($0)" }.joined(separator: "\n"))
                        cardSection("引用金句", output.quote)
                        cardSection("延伸论点", output.extensions.map { "· \($0)" }.joined(separator: "\n"))
                        cardSection("反方视角", output.counter)
                        cardSection("案例提示", output.example)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }

                HStack(spacing: 12) {
                    Spacer()
                    Button("重新生成") {
                        Task { await generate() }
                    }
                    .flatActionButton(height: 32)

                    Button {
                        save(output)
                    } label: {
                        Label("保存到素材卡库", systemImage: "checkmark")
                    }
                    .flatActionButton(.accent, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("把这条书摘扩展成可引用的写作素材")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await generate() }
                    } label: {
                        Label("开始生成", systemImage: "sparkles")
                    }
                    .flatActionButton(.accent, height: 32)
                }
                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
    }

    private func cardSection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(content)
                .font(.system(size: 14))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
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

    private func generate() async {
        guard let apiKey = currentAPIKey, !apiKey.isEmpty else {
            errorMessage = "请先在设置中配置 AI API Key"
            return
        }

        isGenerating = true
        errorMessage = nil
        statusMessage = nil

        let provider = AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "") ?? .openAI
        let service = AIChatService(provider: provider, apiKey: apiKey, model: currentModel)
        let cache = AIResultCache(context: modelContext)
        let quota = AIQuotaTracker()
        let runner = AITaskRunner(service: service, cache: cache, quota: quota)

        let input = WritingCardInput(
            noteID: note.id,
            highlight: note.highlight,
            userNote: note.userNote,
            bookTitle: note.book?.title,
            author: note.book?.author
        )

        do {
            output = try await runner.run(WritingCardTask(), input: input)
            isGenerating = false
        } catch {
            errorMessage = error.localizedDescription
            isGenerating = false
        }
    }

    private func save(_ output: WritingCardOutput) {
        let card = WritingCard(
            noteID: note.id,
            bookTitle: note.book?.title,
            highlight: note.highlight,
            coreIdea: output.coreIdea,
            scenarios: output.scenarios,
            quote: output.quote,
            extensions: output.extensions,
            counter: output.counter,
            example: output.example
        )
        modelContext.insert(card)
        try? modelContext.save()
        statusMessage = "已保存到素材卡库"
    }

    private var currentAPIKey: String? {
        let provider = AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "") ?? .openAI
        return KeychainService.loadAPIKey(for: provider)
    }

    private var currentModel: String {
        let provider = AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "") ?? .openAI
        switch provider {
        case .openAI: return UserDefaults.standard.string(forKey: "openAIModel") ?? provider.defaultModel
        case .deepSeek: return UserDefaults.standard.string(forKey: "deepSeekModel") ?? provider.defaultModel
        case .glm: return UserDefaults.standard.string(forKey: "glmModel") ?? provider.defaultModel
        case .minimax, .aliyun, .doubao: return provider.savedModel
        }
    }
}
