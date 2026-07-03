import Foundation
import SwiftUI

// MARK: - 费曼学习法 (Feynman Technique)
//
// 核心思想：通过"教别人"来检验自己真的理解。
// AI 根据笔记生成测试题，用户作答，AI 评估，反馈学习效果。
//
// 题型：
// - 选择题（理解）
// - 填空题（记忆）
// - 判断题（辨别）
// - 简答题（应用）
// - 关联题（联想其他笔记）

// MARK: - 题目模型

enum FeynmanQuestionType: String, Codable, CaseIterable, Identifiable {
    case multipleChoice = "选择题"
    case fillBlank = "填空题"
    case trueFalse = "判断题"
    case shortAnswer = "简答题"
    case association = "关联题"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .multipleChoice: return "checklist"
        case .fillBlank: return "text.cursor"
        case .trueFalse: return "checkmark.square"
        case .shortAnswer: return "text.alignleft"
        case .association: return "link"
        }
    }

    var accent: String {
        switch self {
        case .multipleChoice: return "blue"
        case .fillBlank: return "purple"
        case .trueFalse: return "orange"
        case .shortAnswer: return "green"
        case .association: return "pink"
        }
    }
}

enum FeynmanDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy = "入门"
    case medium = "应用"
    case hard = "深入"

    var id: String { rawValue }
}

struct FeynmanQuestion: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var type: FeynmanQuestionType
    var difficulty: FeynmanDifficulty
    var prompt: String
    var context: String?  // 引用片段
    var options: [String]?  // 选择题选项
    var correctIndex: Int?  // 选择题正确答案下标
    var correctText: String?  // 填空/简答标准答案
    var explanation: String  // 解析
    var noteID: UUID?  // 关联的笔记
    var userAnswer: String?
    var isCorrect: Bool?

    var questionTypeDisplay: String { type.rawValue }
}

// MARK: - 答题会话

struct FeynmanSession: Codable, Identifiable {
    var id: UUID = UUID()
    var noteIDs: [UUID]
    var questions: [FeynmanQuestion]
    var currentIndex: Int = 0
    var startDate: Date = Date()
    var endDate: Date?
    var style: FeynmanStyle = .feynman

    var score: Double {
        let answered = questions.filter { $0.userAnswer != nil }
        guard !answered.isEmpty else { return 0 }
        let correct = answered.filter { $0.isCorrect == true }.count
        return Double(correct) / Double(answered.count)
    }

    var correctCount: Int {
        questions.filter { $0.isCorrect == true }.count
    }

    var incorrectQuestions: [FeynmanQuestion] {
        questions.filter { $0.isCorrect == false }
    }
}

enum FeynmanStyle: String, Codable, CaseIterable, Identifiable {
    case feynman = "费曼式"
    case exam = "考试式"
    case dialogue = "对话式"
    case application = "应用式"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .feynman: return "用最简单的语言回答，像在教一个孩子"
        case .exam: return "正式考试风格，考验记忆和理解"
        case .dialogue: return "对话式，苏格拉底式提问"
        case .application: return "应用题，考察实际运用能力"
        }
    }
}

// MARK: - 出题服务

enum FeynmanService {
    /// 为单条笔记生成题目
    @MainActor
    static func generateQuestions(
        for note: ReadingNote,
        count: Int = 3,
        style: FeynmanStyle = .feynman,
        provider: AIProvider = .openAI
    ) async throws -> [FeynmanQuestion] {
        let apiKey = KeychainService.loadAPIKey(for: provider) ?? ""
        guard !apiKey.isEmpty else {
            throw FeynmanError.noAPIKey
        }

        let prompt = buildPrompt(for: [note], count: count, style: style)

        let service = AIChatService(
            provider: provider,
            apiKey: apiKey,
            model: modelFor(provider)
        )

        var collected = ""
        for try await chunk in service.askStream(input: prompt) {
            collected += chunk
        }

        return parseQuestions(from: collected, noteIDs: [note.id])
    }

    /// 为多笔记批量出题
    @MainActor
    static func generateQuestions(
        for notes: [ReadingNote],
        count: Int = 5,
        style: FeynmanStyle = .feynman,
        provider: AIProvider = .openAI
    ) async throws -> [FeynmanQuestion] {
        let apiKey = KeychainService.loadAPIKey(for: provider) ?? ""
        guard !apiKey.isEmpty else {
            throw FeynmanError.noAPIKey
        }

        let prompt = buildPrompt(for: notes, count: count, style: style)

        let service = AIChatService(
            provider: provider,
            apiKey: apiKey,
            model: modelFor(provider)
        )

        var collected = ""
        for try await chunk in service.askStream(input: prompt) {
            collected += chunk
        }

        return parseQuestions(from: collected, noteIDs: notes.map(\.id))
    }

    /// 评估用户的简答/填空答案
    @MainActor
    static func evaluateAnswer(
        question: FeynmanQuestion,
        userAnswer: String,
        provider: AIProvider = .openAI
    ) async throws -> FeynmanEvaluation {
        let apiKey = KeychainService.loadAPIKey(for: provider) ?? ""
        guard !apiKey.isEmpty else { throw FeynmanError.noAPIKey }

        let prompt = """
        请评估用户对以下题目的回答。

        题目：\(question.prompt)
        标准答案：\(question.correctText ?? "")
        用户回答：\(userAnswer)

        请按以下 JSON 格式返回评估结果（不要有其他文字）：

        {
          "score": 0-10 的整数,
          "isCorrect": true/false,
          "feedback": "对用户的具体反馈",
          "keyPointsCovered": ["用户答到的关键点"],
          "keyPointsMissing": ["用户没答到的关键点"]
        }
        """

        let service = AIChatService(
            provider: provider,
            apiKey: apiKey,
            model: modelFor(provider)
        )

        var collected = ""
        for try await chunk in service.askStream(input: prompt) {
            collected += chunk
        }

        return try parseEvaluation(from: collected)
    }

    // MARK: - 私有辅助

    private static func buildPrompt(for notes: [ReadingNote], count: Int, style: FeynmanStyle) -> String {
        let styleGuide: String
        switch style {
        case .feynman:
            styleGuide = "用最简单的语言回答，像在教一个 10 岁孩子"
        case .exam:
            styleGuide = "正式考试风格，考验记忆和理解"
        case .dialogue:
            styleGuide = "对话式，苏格拉底式提问"
        case .application:
            styleGuide = "应用题，考察实际运用能力"
        }

        let notesText = notes.prefix(8).map { note -> String in
            """
            【\((note.book?.title ?? "未知书") + (note.chapter.map { " · \($0)" } ?? ""))】
            划线：\(note.highlight)
            \(note.userNote.map { "想法：\($0)" } ?? "")
            """
        }.joined(separator: "\n\n")

        return """
        基于以下笔记生成 \(count) 道测试题。风格：\(style.rawValue)（\(styleGuide)）。

        题型要求（混合）：
        - 选择题：4 个选项，1 个正确答案 + 3 个合理干扰项
        - 填空题：从原文挖掉关键词让用户填
        - 判断题：让用户判断某观点是否正确
        - 简答题：让用户用 1-3 句话回答
        - 关联题：让用户思考该笔记与其他主题的关联

        严格按以下 JSON 数组格式返回（不要任何其他文字）：

        [
          {
            "type": "multipleChoice" / "fillBlank" / "trueFalse" / "shortAnswer" / "association",
            "difficulty": "easy" / "medium" / "hard",
            "prompt": "题目",
            "context": "引用的原文片段（可选）",
            "options": ["A", "B", "C", "D"],   // 仅多选题
            "correctIndex": 0,                  // 仅多选题
            "correctText": "标准答案",           // 填空/简答/关联
            "explanation": "为什么这么答"
          }
        ]

        笔记内容：
        \(notesText)
        """
    }

    private static func parseQuestions(from json: String, noteIDs: [UUID]) -> [FeynmanQuestion] {
        // 提取 JSON 数组
        guard let start = json.firstIndex(of: "["),
              let end = json.lastIndex(of: "]") else {
            return []
        }
        let jsonStr = String(json[start...end])

        struct RawQuestion: Decodable {
            let type: String
            let difficulty: String
            let prompt: String
            let context: String?
            let options: [String]?
            let correctIndex: Int?
            let correctText: String?
            let explanation: String
        }

        guard let data = jsonStr.data(using: .utf8),
              let raw = try? JSONDecoder().decode([RawQuestion].self, from: data) else {
            return []
        }

        return raw.enumerated().map { idx, item in
            FeynmanQuestion(
                id: UUID(),
                type: parseType(item.type),
                difficulty: parseDifficulty(item.difficulty),
                prompt: item.prompt,
                context: item.context,
                options: item.options,
                correctIndex: item.correctIndex,
                correctText: item.correctText,
                explanation: item.explanation,
                noteID: noteIDs[idx % noteIDs.count]
            )
        }
    }

    private static func parseType(_ s: String) -> FeynmanQuestionType {
        switch s.lowercased() {
        case "multiplechoice", "multiple_choice": return .multipleChoice
        case "fillblank", "fill_blank", "fill": return .fillBlank
        case "truefalse", "true_false": return .trueFalse
        case "shortanswer", "short_answer": return .shortAnswer
        case "association": return .association
        default: return .shortAnswer
        }
    }

    private static func parseDifficulty(_ s: String) -> FeynmanDifficulty {
        switch s.lowercased() {
        case "easy": return .easy
        case "hard": return .hard
        default: return .medium
        }
    }

    private static func modelFor(_ provider: AIProvider) -> String {
        switch provider {
        case .openAI: return AIProvider.openAI.defaultModel
        case .deepSeek: return AIProvider.deepSeek.defaultModel
        case .glm: return AIProvider.glm.defaultModel
        case .minimax, .aliyun, .doubao: return provider.savedModel
        }
    }
}

// MARK: - 评估结果

struct FeynmanEvaluation: Codable {
    let score: Int        // 0-10
    let isCorrect: Bool
    let feedback: String
    let keyPointsCovered: [String]
    let keyPointsMissing: [String]
}

extension FeynmanService {
    enum FeynmanError: LocalizedError {
        case noAPIKey
        case parseError

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "未配置 AI API Key，请先在设置中配置"
            case .parseError: return "AI 返回内容解析失败"
            }
        }
    }

    fileprivate static func parseEvaluation(from json: String) throws -> FeynmanEvaluation {
        guard let start = json.firstIndex(of: "{"),
              let end = json.lastIndex(of: "}") else {
            throw FeynmanError.parseError
        }
        let jsonStr = String(json[start...end])
        guard let data = jsonStr.data(using: .utf8),
              let evalResult = try? JSONDecoder().decode(FeynmanEvaluation.self, from: data) else {
            throw FeynmanError.parseError
        }
        return evalResult
    }
}

// MARK: - 错题本

struct MistakeBook: Codable {
    var entries: [MistakeEntry] = []

    struct MistakeEntry: Codable, Identifiable, Hashable {
        var id: UUID = UUID()
        var questionID: UUID
        var question: FeynmanQuestion
        var userAnswer: String?
        var mistakeDate: Date
        var resolvedCount: Int = 0  // 答对次数
    }

    static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return support.appendingPathComponent("书摘温故/mistake-book.json")
    }

    static func load() -> MistakeBook {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let book = try? JSONDecoder().decode(MistakeBook.self, from: data) else {
            return MistakeBook()
        }
        return book
    }

    static func save(_ book: MistakeBook) {
        guard let data = try? JSONEncoder().encode(book) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    mutating func add(question: FeynmanQuestion, userAnswer: String?) {
        let entry = MistakeEntry(
            questionID: question.id,
            question: question,
            userAnswer: userAnswer,
            mistakeDate: Date()
        )
        // 合并相同问题
        if let idx = entries.firstIndex(where: { $0.questionID == question.id }) {
            entries[idx].mistakeDate = Date()
            entries[idx].userAnswer = userAnswer
        } else {
            entries.append(entry)
        }
    }

    mutating func markResolved(questionID: UUID) {
        if let idx = entries.firstIndex(where: { $0.questionID == questionID }) {
            entries[idx].resolvedCount += 1
            // 连续答对 3 次自动移除
            if entries[idx].resolvedCount >= 3 {
                entries.remove(at: idx)
            }
        }
    }
}

@MainActor
@Observable
final class MistakeBookStore {
    static let shared = MistakeBookStore()

    var book: MistakeBook = MistakeBook.load()

    private init() {}

    func recordMistake(question: FeynmanQuestion, userAnswer: String?) {
        book.add(question: question, userAnswer: userAnswer)
        MistakeBook.save(book)
    }

    func markResolved(questionID: UUID) {
        book.markResolved(questionID: questionID)
        MistakeBook.save(book)
    }

    func contains(_ question: FeynmanQuestion) -> Bool {
        book.entries.contains { $0.questionID == question.id }
    }
}
