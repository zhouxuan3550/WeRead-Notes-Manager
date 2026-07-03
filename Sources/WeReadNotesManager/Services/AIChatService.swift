import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case openAI
    case deepSeek
    case glm
    case minimax
    case aliyun
    case doubao

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openAI: return "OpenAI"
        case .deepSeek: return "DeepSeek"
        case .glm: return "GLM"
        case .minimax: return "MiniMax"
        case .aliyun: return "阿里云"
        case .doubao: return "豆包"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4.1-mini"
        case .deepSeek: return "deepseek-chat"
        case .glm: return "glm-4-flash"
        case .minimax: return "MiniMax-M3"
        case .aliyun: return "qwen-plus"
        case .doubao: return "doubao-seed-1-6-flash"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openAI: return "sk- 开头的 OpenAI Key"
        case .deepSeek: return "sk- 开头的 DeepSeek Key"
        case .glm: return "智谱 AI / GLM API Key"
        case .minimax: return "MiniMax API Key"
        case .aliyun: return "阿里云百炼 API Key"
        case .doubao: return "火山方舟 / 豆包 API Key"
        }
    }

    var modelDefaultsKey: String {
        switch self {
        case .openAI: return "openAIModel"
        case .deepSeek: return "deepSeekModel"
        case .glm: return "glmModel"
        case .minimax: return "minimaxModel"
        case .aliyun: return "aliyunModel"
        case .doubao: return "doubaoModel"
        }
    }

    var endpoint: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .deepSeek:
            return "https://api.deepseek.com/chat/completions"
        case .glm:
            return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        case .minimax:
            return "https://api.minimax.io/v1/chat/completions"
        case .aliyun:
            return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        case .doubao:
            return "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
        }
    }

    var savedModel: String {
        let value = UserDefaults.standard.string(forKey: modelDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? defaultModel : value
    }
}

struct AIChatService {
    let provider: AIProvider
    let apiKey: String
    let model: String

    /// 兼容旧调用方：把流式结果聚合成一个完整字符串返回。
    @available(*, deprecated, message: "Use askStream for incremental rendering")
    func ask(input: String) async throws -> String {
        var collected = ""
        for try await chunk in askStream(input: input) {
            collected += chunk
        }
        return collected
    }

    /// RAG 增强：先检索相关笔记，再用 AI 回答。
    /// - Parameters:
    ///   - question: 用户问题
    ///   - context: 检索出来的相关笔记（已经格式化）
    /// - Returns: 流式文本流
    func askWithContext(question: String, context: String) -> AsyncThrowingStream<String, Error> {
        let input = """
        下面是用户笔记库中与问题最相关的片段：

        \(context)

        用户问题：
        \(question)

        要求：
        1. 仅基于上述片段回答，不要编造笔记中不存在的内容
        2. 引用具体片段时标注 [片段 N]
        3. 如果片段不足以回答，明确告知用户
        """
        return askStream(input: input)
    }

    /// 整本书总结（Feature 9）。
    func summarizeBook(title: String, author: String?, context: String) -> AsyncThrowingStream<String, Error> {
        let authorLine = author.map { "（作者：\($0)）" } ?? ""
        let input = """
        请基于以下用户从《\(title)》\(authorLine)中记录的划线和想法，整理出一份结构化的读书总结。

        要求：
        1. 【核心思想】用 3-5 个 bullet 提炼全书的中心论点
        2. 【关键主题】列出 3-5 个反复出现的主题，每个主题配 1-2 条最有代表性的原文摘录
        3. 【思考脉络】根据用户的「我的想法」梳理出他们的思考演化
        4. 【金句】挑出 5 条最值得反复回味的划线
        5. 【行动启发】基于用户想法，给出 3 条可执行的行动建议

        用户笔记：
        \(context)
        """
        return askStream(input: input)
    }
    ///
    /// 用法：
    /// ```swift
    /// for try await delta in service.askStream(input: prompt) {
    ///     answer += delta
    /// }
    /// ```
    func askStream(input: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: provider.endpoint) else {
                        throw AIChatServiceError.invalidURL
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 75
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: [
                        "model": model.isEmpty ? provider.defaultModel : model,
                        "messages": [
                            [
                                "role": "system",
                                "content": "你是一个帮助用户深度理解阅读笔记的中文阅读伙伴。回答要具体、有判断，不要空泛总结。"
                            ],
                            [
                                "role": "user",
                                "content": input
                            ]
                        ],
                        "temperature": 0.7,
                        "stream": true
                    ])

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                        var errorData = Data()
                        for try await byte in bytes { errorData.append(byte) }
                        let message = AIChatResponseParser.errorMessage(from: errorData) ?? "请求失败，状态码 \(httpResponse.statusCode)。"
                        throw AIChatServiceError.requestFailed(message)
                    }

                    var pending = ""
                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { continue }
                        if trimmed == "data: [DONE]" { break }
                        if trimmed.hasPrefix("data:") {
                            let json = String(trimmed.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces)
                            if let delta = AIChatResponseParser.streamDelta(from: Data(json.utf8)) {
                                if !delta.isEmpty {
                                    continuation.yield(delta)
                                }
                            }
                        }
                        pending = trimmed
                    }
                    if pending.isEmpty {
                        // 服务端没有以 [DONE] 收尾，但也没流过任何内容 → 抛空响应
                        throw AIChatServiceError.emptyResponse
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    AppLog.error("AI 流式调用失败", error: error, category: .ai)
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

private enum AIChatResponseParser {
    /// 解析一次性的 chat 响应。
    static func outputText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first else {
            return nil
        }

        if let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let text = first["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    /// 解析流式 SSE chunk 的 delta 字段。
    ///
    /// 兼容三种结构：
    /// 1. OpenAI / DeepSeek: `choices[0].delta.content`
    /// 2. GLM: `choices[0].delta.content` 或 `choices[0].text`
    /// 3. 旧版: `choices[0].message.content`
    static func streamDelta(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first else {
            return nil
        }

        if let delta = first["delta"] as? [String: Any] {
            if let content = delta["content"] as? String { return content }
            if let content = delta["text"] as? String { return content }
        }
        if let message = first["message"] as? [String: Any] {
            if let content = message["content"] as? String { return content }
        }
        if let text = first["text"] as? String { return text }
        return ""
    }

    static func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        if let message = json["message"] as? String {
            return message
        }
        return nil
    }
}

enum AIChatServiceError: LocalizedError {
    case invalidURL
    case requestFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "AI 接口地址无效。"
        case .requestFailed(let message):
            return message
        case .emptyResponse:
            return "AI 没有返回可显示的内容。"
        }
    }
}
