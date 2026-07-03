import Foundation
import CryptoKit

// MARK: - 错误

enum AITaskError: LocalizedError {
    case quotaExceeded
    case parsingFailed(String)
    case noAPIKey
    case jsonExtractionFailed

    var errorDescription: String? {
        switch self {
        case .quotaExceeded:
            return "今日 AI 调用次数已达上限，升级 Pro 可无限使用。"
        case .parsingFailed(let detail):
            return "AI 返回解析失败：\(detail)"
        case .noAPIKey:
            return "请先在设置中配置 AI API Key。"
        case .jsonExtractionFailed:
            return "无法从 AI 返回中提取结构化数据。"
        }
    }
}

// MARK: - 协议

/// AI 任务的统一抽象。
protocol AITask: Sendable {
    associatedtype Input: Hashable & Sendable
    associatedtype Output: Sendable

    var taskID: String { get }
    var displayName: String { get }

    /// 是否需要按输入缓存。默认 true。
    var shouldCache: Bool { get }

    /// 构造 prompt。
    func buildPrompt(input: Input) -> String

    /// 把 AI 返回的文本解析为结构化输出。
    func parse(_ raw: String) throws -> Output

    /// 生成缓存 key。默认基于输入哈希。
    func cacheKey(for input: Input) -> String
}

extension AITask {
    var shouldCache: Bool { true }

    func cacheKey(for input: Input) -> String {
        let base = "\(input.hashValue):\(String(describing: input))"
        return String(SHA256.hash(string: "\(taskID):\(base)").prefix(16))
    }
}

// MARK: - Runner

/// 统一的 AI 任务执行器。
@MainActor
final class AITaskRunner {
    private let service: AIChatService
    private let cache: AIResultCache
    private let quota: AIQuotaTracker

    init(service: AIChatService, cache: AIResultCache, quota: AIQuotaTracker) {
        self.service = service
        self.cache = cache
        self.quota = quota
    }

    /// 执行任务。优先读缓存；未命中则调用 AI，并写入缓存。
    func run<T: AITask>(_ task: T, input: T.Input) async throws -> T.Output {
        let key = task.cacheKey(for: input)

        if task.shouldCache, let cached = cache.load(taskID: task.taskID, key: key) {
            if let output = try? task.parse(cached) {
                return output
            }
        }

        guard quota.consume(taskID: task.taskID) else {
            throw AITaskError.quotaExceeded
        }

        let prompt = task.buildPrompt(input: input)
        var raw = ""
        for try await chunk in service.askStream(input: prompt) {
            raw += chunk
        }

        let output = try task.parse(raw)

        if task.shouldCache {
            cache.save(taskID: task.taskID, key: key, raw: raw)
        }

        return output
    }

    /// 流式执行任务。返回结构化结果 + 思考过程文本。
    /// 注意：流式任务不写入缓存，最终完整内容交给调用方处理。
    func runStream<T: AITask>(_ task: T, input: T.Input) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let taskExecutor = Task {
                do {
                    guard quota.consume(taskID: task.taskID) else {
                        throw AITaskError.quotaExceeded
                    }

                    let prompt = task.buildPrompt(input: input)
                    for try await chunk in service.askStream(input: prompt) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                taskExecutor.cancel()
            }
        }
    }
}

// MARK: - 工具函数

func extractJSON(from raw: String) throws -> Data {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    // 优先找 ```json ... ``` 代码块
    if let startRange = trimmed.range(of: "```json"),
       let endRange = trimmed[startRange.upperBound...].range(of: "```") {
        let json = String(trimmed[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Data(json.utf8)
    }

    // 再找 ``` ... ```
    if let startRange = trimmed.range(of: "```"),
       let endRange = trimmed[startRange.upperBound...].range(of: "```") {
        let json = String(trimmed[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Data(json.utf8)
    }

    // 找第一个 { 和最后一个 }
    if let first = trimmed.firstIndex(of: "{"),
       let last = trimmed.lastIndex(of: "}") {
        let json = String(trimmed[first...last])
        return Data(json.utf8)
    }

    throw AITaskError.jsonExtractionFailed
}

extension SHA256 {
    static func hash(string: String) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension Date {
    /// 用于配额重置的日期字符串。
    var quotaDayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: self)
    }
}
