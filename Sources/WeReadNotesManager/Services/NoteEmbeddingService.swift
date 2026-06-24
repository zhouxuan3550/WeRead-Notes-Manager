import Foundation
import NaturalLanguage
import SwiftData

/// 给笔记生成 embedding，提供语义检索能力。
///
/// 使用 macOS 内置的 `NLEmbedding`（无需外部 API/网络），512 维向量。
/// 首次使用时会下载英文 + 中文模型（约几百 MB）。
///
/// 实际生产可用 `all-MiniLM-L6-v2` 等本地模型；这里为了零依赖选系统 API。
@MainActor
final class NoteEmbeddingService {
    static let shared = NoteEmbeddingService()

    private let embedding: NLEmbedding?

    private init() {
        // 优先尝试中文 sentence embedding；失败则降级到英文
        if let zh = NLEmbedding.sentenceEmbedding(for: .simplifiedChinese) {
            self.embedding = zh
        } else if let en = NLEmbedding.sentenceEmbedding(for: .english) {
            self.embedding = en
        } else {
            self.embedding = nil
        }
    }

    var isAvailable: Bool { embedding != nil }

    /// 给一条笔记生成 embedding；不可用时返回 nil。
    func embed(_ note: ReadingNote) -> [Double]? {
        guard let embedding else { return nil }
        let text = buildText(for: note)
        return embedding.vector(for: text)
    }

    func embed(text: String) -> [Double]? {
        guard let embedding else { return nil }
        return embedding.vector(for: text)
    }

    private func buildText(for note: ReadingNote) -> String {
        var parts: [String] = []
        if let bookTitle = note.book?.title {
            parts.append(bookTitle)
        }
        if let chapter = note.chapter, !chapter.isEmpty {
            parts.append(chapter)
        }
        parts.append(note.highlight)
        if let userNote = note.userNote, !userNote.isEmpty {
            parts.append(userNote)
        }
        return parts.joined(separator: "。")
    }
}

/// RAG 检索器：用 embedding 找出与 query 最相关的笔记。
@MainActor
struct NoteRetriever {
    let notes: [ReadingNote]
    let embeddingService: NoteEmbeddingService

    init(notes: [ReadingNote], embeddingService: NoteEmbeddingService = .shared) {
        self.notes = notes.filter { !$0.isDeleted }
        self.embeddingService = embeddingService
    }

    /// 返回 top-k 最相关的笔记（按相似度倒序）。
    func topK(query: String, k: Int = 10) -> [(note: ReadingNote, score: Double)] {
        guard embeddingService.isAvailable else {
            // 降级：返回最近的 k 条
            return Array(notes.prefix(k)).map { ($0, 0.0) }
        }
        guard let queryVec = embeddingService.embed(text: query) else {
            return Array(notes.prefix(k)).map { ($0, 0.0) }
        }

        var scored: [(ReadingNote, Double)] = []
        for note in notes {
            guard let noteVec = embeddingService.embed(note) else { continue }
            let sim = cosineSimilarity(queryVec, noteVec)
            scored.append((note, sim))
        }
        scored.sort { $0.1 > $1.1 }
        return Array(scored.prefix(k))
    }

    /// 把 top-k 笔记拼成 context 字符串，供 AI prompt 使用。
    func contextString(for query: String, k: Int = 10) -> String {
        let top = topK(query: query, k: k)
        return top.enumerated().map { index, pair in
            let book = pair.note.book?.title ?? "未知书籍"
            let chapter = pair.note.chapter ?? ""
            let highlight = pair.note.highlight
            let userNote = pair.note.userNote.map { "\n我的想法：\($0)" } ?? ""
            return """
            [片段 \(index + 1)] 来源：\(book)\(chapter.isEmpty ? "" : " · \(chapter)")
            \(highlight)\(userNote)
            """
        }.joined(separator: "\n\n")
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }
        var dot: Double = 0
        var normA: Double = 0
        var normB: Double = 0
        for i in 0..<n {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = (normA.squareRoot()) * (normB.squareRoot())
        return denom == 0 ? 0 : dot / denom
    }
}