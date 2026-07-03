import Foundation

// MARK: - 输入

struct AutoTagNoteInput: Codable, Hashable, Sendable {
    let highlight: String
    let userNote: String?
    let bookTitle: String?
    let chapter: String?
}

// MARK: - 输出

struct NoteTagProposal: Codable, Sendable, Equatable {
    let name: String
    let confidence: Double
    let noteIndices: [Int]

    enum CodingKeys: String, CodingKey {
        case name
        case confidence
        case noteIndices = "note_indices"
    }
}

struct AutoTagResponse: Codable, Sendable {
    let tags: [NoteTagProposal]
}

// MARK: - Task

struct AutoTagTask: AITask {
    typealias Input = [AutoTagNoteInput]
    typealias Output = [NoteTagProposal]

    let taskID = "auto-tag"
    let displayName = "AI 自动标签"

    func buildPrompt(input: [AutoTagNoteInput]) -> String {
        let notesText = input.prefix(30).enumerated().map { index, note in
            var s = "[\(index)] 《\(note.bookTitle ?? "未知")》\(note.chapter.map { " · \($0)" } ?? "")\n划线：\(note.highlight)"
            if let userNote = note.userNote, !userNote.isEmpty {
                s += "\n想法：\(userNote)"
            }
            return s
        }.joined(separator: "\n\n")

        return """
        请为以下读书笔记推荐 3-10 个标签。标签应该：
        1. 概括主题（如"决策""习惯""认知偏差""领导力"）
        2. 不要包含书名、作者名
        3. 使用中文，简洁，2-6 个字
        4. 输出严格 JSON 格式，不要任何其他文字

        JSON 格式：
        {
          "tags": [
            { "name": "决策", "confidence": 0.95, "note_indices": [0, 2] },
            { "name": "习惯", "confidence": 0.88, "note_indices": [1] }
          ]
        }

        笔记：
        \(notesText)
        """
    }

    func parse(_ raw: String) throws -> [NoteTagProposal] {
        let data = try extractJSON(from: raw)
        let decoded = try JSONDecoder().decode(AutoTagResponse.self, from: data)
        return decoded.tags.sorted { $0.confidence > $1.confidence }
    }
}
