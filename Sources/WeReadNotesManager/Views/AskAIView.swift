import AppKit
import SwiftUI

struct AskAIView: View {
    let note: ReadingNote
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
    @State private var question = "解释这条书摘的核心意思，并给我 3 个可以继续思考的问题。"
    @State private var answer = ""
    @State private var statusMessage: String?
    @State private var isAsking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    quotePreview
                    keyPanel
                    questionPanel
                    if !answer.isEmpty {
                        answerPanel
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(22)
        .frame(width: 620, height: 680)
        .background(AppBackdrop())
        .onAppear {
            provider = AIProvider(rawValue: aiProviderRaw) ?? .openAI
            apiKey = KeychainService.loadAPIKey(for: provider) ?? ""
        }
        .onChange(of: provider) { _, newProvider in
            aiProviderRaw = newProvider.rawValue
            apiKey = KeychainService.loadAPIKey(for: newProvider) ?? ""
            statusMessage = nil
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(.blue.opacity(0.18)))

            VStack(alignment: .leading, spacing: 3) {
                Text("问 AI")
                    .font(.system(size: 20, weight: .semibold))
                Text(note.book?.title ?? "当前书摘")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("关闭") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var quotePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前书摘")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(note.highlight)
                .font(.system(size: 15))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let userNote = note.userNote, !userNote.isEmpty {
                Divider()
                Text(userNote)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
        }
        .padding(14)
        .glassPanel()
    }

    private var keyPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI 设置")
                .font(.system(size: 13, weight: .semibold))

            providerSelector
            .disabled(isAsking)

            SecureField(provider.keyPlaceholder, text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .disabled(isAsking)

            HStack(spacing: 10) {
                Text("模型")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField(provider.defaultModel, text: modelBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)

                Spacer()

                Button {
                    pasteAPIKey()
                } label: {
                    Label("粘贴 Key", systemImage: "doc.on.clipboard")
                }
                .flatActionButton(height: 30)
                .disabled(isAsking)

                Button {
                    saveAPIKey()
                } label: {
                    Label("保存 Key", systemImage: "key")
                }
                .flatActionButton(height: 30)
                .disabled(isAsking || cleanedAPIKey.isEmpty)
            }
        }
        .padding(14)
        .glassPanel()
    }

    private var providerSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(AIProvider.allCases.enumerated()), id: \.element) { index, item in
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

                if index < AIProvider.allCases.count - 1 {
                    Rectangle()
                        .fill(palette.borderSubtle)
                        .frame(width: 0.8, height: 16)
                }
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

    private var questionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("你想问什么")
                .font(.system(size: 13, weight: .semibold))

            TextEditor(text: $question)
                .font(.system(size: 14))
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.thinMaterial))

            HStack {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    askAI()
                } label: {
                    Label(isAsking ? "思考中..." : "提问", systemImage: "paperplane")
                }
                .flatActionButton(.accent, height: 32)
                .disabled(isAsking || cleanedAPIKey.isEmpty || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .glassPanel()
    }

    private var answerPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI 回答")
                .font(.system(size: 13, weight: .semibold))
            Text(answer)
                .font(.system(size: 14))
                .lineSpacing(5)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .glassPanel()
    }

    private var cleanedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func pasteAPIKey() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            statusMessage = "剪贴板里没有可粘贴的文本。"
            return
        }
        apiKey = text.trimmingCharacters(in: .whitespacesAndNewlines)
        saveAPIKey()
    }

    private func saveAPIKey() {
        do {
            try KeychainService.saveAPIKey(cleanedAPIKey, for: provider)
            statusMessage = "\(provider.label) Key 已保存到本机 Keychain。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func askAI() {
        saveAPIKey()
        isAsking = true
        statusMessage = "正在向 AI 提问..."
        answer = ""

        let service = AIChatService(
            provider: provider,
            apiKey: cleanedAPIKey,
            model: currentModel.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Task {
            do {
                for try await delta in service.askStream(input: prompt) {
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

    private var prompt: String {
        """
        你是一个帮助用户深度理解阅读笔记的中文阅读伙伴。请结合书名、章节、划线和我的想法回答，不要空泛总结。

        书名：\(note.book?.title ?? "未知")
        作者：\(note.book?.author ?? "未知")
        章节：\(note.chapter ?? "未知")
        划线：\(note.highlight)
        我的想法：\(note.userNote ?? "无")

        问题：\(question.trimmingCharacters(in: .whitespacesAndNewlines))
        """
    }
}
