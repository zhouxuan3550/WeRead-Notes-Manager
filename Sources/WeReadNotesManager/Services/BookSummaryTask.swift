import Foundation

// MARK: - 输出

struct StructuredBookSummary: Codable, Sendable {
    let coreIdeas: [String]
    let themes: [BookTheme]
    let thinkingThread: String
    let quotes: [String]
    let actionItems: [String]

    enum CodingKeys: String, CodingKey {
        case coreIdeas = "core_ideas"
        case themes
        case thinkingThread = "thinking_thread"
        case quotes
        case actionItems = "action_items"
    }
}

struct BookTheme: Codable, Sendable {
    let name: String
    let notes: [String]
}

// MARK: - Task

struct BookSummaryTask: AITask {
    typealias Input = BookSummaryInput
    typealias Output = StructuredBookSummary

    let taskID = "book-summary"
    let displayName = "单书总结"

    func buildPrompt(input: Input) -> String {
        """
        请基于以下用户从《\(input.title)》\(input.author.map { "（作者：\($0)）" } ?? "")中记录的划线和想法，整理出一份结构化的读书总结。

        要求：
        1. core_ideas：3-5 个 bullet 提炼全书中心论点
        2. themes：3-5 个反复出现的主题，每个主题配 1-2 条最有代表性的原文摘录
        3. thinking_thread：根据用户的「我的想法」梳理出他们的思考演化，一段话
        4. quotes：5 条最值得反复回味的划线
        5. action_items：3 条可执行的行动建议

        输出严格 JSON，不要任何其他文字：
        {
          "core_ideas": ["..."],
          "themes": [
            { "name": "主题名", "notes": ["摘录1", "摘录2"] }
          ],
          "thinking_thread": "...",
          "quotes": ["..."],
          "action_items": ["..."]
        }

        用户笔记：
        \(input.context)
        """
    }

    func parse(_ raw: String) throws -> StructuredBookSummary {
        let data = try extractJSON(from: raw)
        return try JSONDecoder().decode(StructuredBookSummary.self, from: data)
    }
}

struct BookSummaryInput: Codable, Hashable, Sendable {
    let title: String
    let author: String?
    let context: String
}
