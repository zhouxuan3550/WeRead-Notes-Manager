import Foundation

// MARK: - 输出

struct TopicClusterNamingResponse: Codable, Sendable {
    let name: String
    let summary: String
}

// MARK: - Task

struct TopicNamingTask: AITask {
    typealias Input = TopicNamingInput
    typealias Output = TopicClusterNamingResponse

    let taskID = "topic-naming"
    let displayName = "主题命名"

    func buildPrompt(input: Input) -> String {
        let notesText = input.notes.enumerated().map { index, note in
            "[\(index)] \(note.highlight)" + (note.userNote.map { "\n想法：\($0)" } ?? "")
        }.joined(separator: "\n\n")

        let keywords = input.keywords.joined(separator: "、")

        return """
        请为以下一簇读书笔记起一个主题名称，并写一句不超过 60 字的摘要。
        主题名称要求：
        1. 中文，2-8 个字
        2. 概括这组笔记的共同主题
        3. 不要包含书名、作者名

        关键词参考：\(keywords)

        笔记：
        \(notesText)

        输出严格 JSON：
        {
          "name": "主题名称",
          "summary": "一句话摘要"
        }
        """
    }

    func parse(_ raw: String) throws -> TopicClusterNamingResponse {
        let data = try extractJSON(from: raw)
        return try JSONDecoder().decode(TopicClusterNamingResponse.self, from: data)
    }
}

struct TopicNamingInput: Codable, Hashable, Sendable {
    let notes: [TopicNamingNote]
    let keywords: [String]
}

struct TopicNamingNote: Codable, Hashable, Sendable {
    let highlight: String
    let userNote: String?
}
