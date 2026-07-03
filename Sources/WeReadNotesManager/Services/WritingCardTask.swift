import Foundation

// MARK: - 输入

struct WritingCardInput: Codable, Hashable, Sendable {
    let noteID: UUID
    let highlight: String
    let userNote: String?
    let bookTitle: String?
    let author: String?
}

// MARK: - 输出

struct WritingCardOutput: Codable, Sendable {
    let coreIdea: String
    let scenarios: [String]
    let quote: String
    let extensions: [String]
    let counter: String
    let example: String

    enum CodingKeys: String, CodingKey {
        case coreIdea = "core_idea"
        case scenarios
        case quote
        case extensions
        case counter
        case example
    }
}

// MARK: - Task

struct WritingCardTask: AITask {
    typealias Input = WritingCardInput
    typealias Output = WritingCardOutput

    let taskID = "writing-card"
    let displayName = "写作素材卡"

    func buildPrompt(input: WritingCardInput) -> String {
        """
        请把以下书摘扩展成一张"写作素材卡"，包含：
        1. core_idea：用一句话概括核心观点
        2. scenarios：适合讨论什么话题（3-5 个）
        3. quote：保留最有力的原文句子
        4. extensions：可以怎么展开这个观点（2-3 个）
        5. counter：可能的反对意见
        6. example：可以举什么例子

        输出严格 JSON，不要任何其他文字：
        {
          "core_idea": "...",
          "scenarios": ["..."],
          "quote": "...",
          "extensions": ["..."],
          "counter": "...",
          "example": "..."
        }

        书摘：\(input.highlight)
        我的想法：\(input.userNote ?? "无")
        书名：\(input.bookTitle ?? "未知")
        作者：\(input.author ?? "未知")
        """
    }

    func parse(_ raw: String) throws -> WritingCardOutput {
        let data = try extractJSON(from: raw)
        return try JSONDecoder().decode(WritingCardOutput.self, from: data)
    }
}
