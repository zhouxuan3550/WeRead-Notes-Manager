import AppKit
import SwiftUI

struct AITextRequest: Identifiable {
    let id = UUID()
    let title: String
    let context: String
    let defaultQuestion: String
}

struct AITextWorkbenchView: View {
    let request: AITextRequest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themePalette) private var palette
    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.openAI.rawValue
    @AppStorage("openAIModel") private var openAIModel = AIProvider.openAI.defaultModel
    @AppStorage("deepSeekModel") private var deepSeekModel = AIProvider.deepSeek.defaultModel
    @AppStorage("glmModel") private var glmModel = AIProvider.glm.defaultModel
    @AppStorage("minimaxModel") private var minimaxModel = AIProvider.minimax.defaultModel
    @AppStorage("aliyunModel") private var aliyunModel = AIProvider.aliyun.defaultModel
    @AppStorage("doubaoModel") private var doubaoModel = AIProvider.doubao.defaultModel
    @State private var provider: AIProvider = .openAI
    @State private var apiKey = ""
    @State private var question = ""
    @State private var answer = ""
    @State private var statusMessage: String?
    @State private var isAsking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.title)
                        .font(.system(size: 19, weight: .semibold))
                    Text(provider.label)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            providerSelector
                .disabled(isAsking)

            HStack(spacing: 10) {
                SecureField(provider.keyPlaceholder, text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                TextField(provider.defaultModel, text: modelBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                Button("保存 Key") { saveKey() }
                    .flatActionButton(height: 30)
                    .disabled(cleanedAPIKey.isEmpty)
            }

            TextEditor(text: $question)
                .font(.system(size: 14))
                .frame(height: 110)
                .scrollContentBackground(.hidden)
                .padding(8)
                .appFieldSurface()

            HStack {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    ask()
                } label: {
                    Label(isAsking ? "思考中..." : "提问", systemImage: "paperplane")
                }
                .flatActionButton(.accent, height: 32)
                .disabled(isAsking || cleanedAPIKey.isEmpty || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ScrollView {
                Text(answer.isEmpty ? "AI 回答会显示在这里。" : answer)
                    .font(.system(size: 14))
                    .foregroundStyle(answer.isEmpty ? .secondary : .primary)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .appFieldSurface()
        }
        .padding(22)
        .frame(width: 680, height: 720)
        .background(AppBackdrop())
        .onAppear {
            provider = AIProvider(rawValue: aiProviderRaw) ?? .openAI
            apiKey = KeychainService.loadAPIKey(for: provider) ?? ""
            question = request.defaultQuestion
        }
        .onChange(of: provider) { _, newProvider in
            aiProviderRaw = newProvider.rawValue
            apiKey = KeychainService.loadAPIKey(for: newProvider) ?? ""
        }
    }

    private var cleanedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var providerSelector: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
            spacing: 2
        ) {
            ForEach(AIProvider.allCases) { item in
                Button {
                    provider = item
                } label: {
                    Text(item.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(provider == item ? palette.textPrimary : palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(provider == item ? palette.surfaceElevated.opacity(0.72) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(palette.surface.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 0.8)
        )
    }

    private var currentModel: String {
        switch provider {
        case .openAI: return openAIModel
        case .deepSeek: return deepSeekModel
        case .glm: return glmModel
        case .minimax: return minimaxModel
        case .aliyun: return aliyunModel
        case .doubao: return doubaoModel
        }
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { currentModel },
            set: { value in
                switch provider {
                case .openAI: openAIModel = value
                case .deepSeek: deepSeekModel = value
                case .glm: glmModel = value
                case .minimax: minimaxModel = value
                case .aliyun: aliyunModel = value
                case .doubao: doubaoModel = value
                }
            }
        )
    }

    private func saveKey() {
        do {
            try KeychainService.saveAPIKey(cleanedAPIKey, for: provider)
            statusMessage = "\(provider.label) Key 已保存。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func ask() {
        saveKey()
        isAsking = true
        answer = ""
        statusMessage = "正在生成..."

        let input = """
        下面是阅读上下文：

        \(request.context)

        用户问题：
        \(question.trimmingCharacters(in: .whitespacesAndNewlines))
        """

        let service = AIChatService(provider: provider, apiKey: cleanedAPIKey, model: currentModel)
        Task {
            do {
                for try await delta in service.askStream(input: input) {
                    answer += delta
                }
                statusMessage = "已完成。"
                isAsking = false
            } catch {
                statusMessage = error.localizedDescription
                isAsking = false
            }
        }
    }
}
