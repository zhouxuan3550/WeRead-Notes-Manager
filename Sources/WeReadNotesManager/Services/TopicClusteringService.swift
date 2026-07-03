import Foundation
import NaturalLanguage

// MARK: - 本地主题聚类

/// 基于 NLEmbedding 的本地 K-Means 聚类。
@MainActor
final class TopicClusteringService {
    static let shared = TopicClusteringService()

    private let embeddingService = NoteEmbeddingService.shared

    /// 对笔记进行聚类。
    /// - Parameters:
    ///   - notes: 待聚类笔记
    ///   - k: 期望主题数（最终可能略少）
    /// - Returns: 每个簇包含的笔记索引
    func cluster(notes: [ReadingNote], k: Int = 6) -> [[Int]] {
        guard embeddingService.isAvailable, notes.count >= 3 else {
            return fallbackClusters(notes: notes)
        }

        let vectors: [(index: Int, vector: [Double])] = notes.enumerated().compactMap { index, note in
            guard let vector = embeddingService.embed(note) else { return nil }
            return (index, vector)
        }

        guard vectors.count >= k else {
            return fallbackClusters(notes: notes)
        }

        let actualK = min(k, vectors.count / 2 + 1)
        let clusterIndices = kMeans(vectors: vectors.map { $0.vector }, k: actualK, maxIterations: 30)

        var groups: [[Int]] = Array(repeating: [], count: actualK)
        for (vectorIndex, groupIndex) in clusterIndices.enumerated() {
            groups[groupIndex].append(vectors[vectorIndex].index)
        }

        return groups.filter { !$0.isEmpty }
    }

    /// 提取每个簇的关键词：基于高频词 + 共现。
    func keywords(for notes: [ReadingNote], indices: [Int]) -> [String] {
        let selected = indices.map { notes[$0] }
        let text = selected.map { note in
            [note.book?.title, note.chapter, note.highlight, note.userNote]
                .compactMap { $0 }
                .joined(separator: " ")
        }.joined(separator: " ")

        return extractKeywords(from: text, top: 8)
    }

    // MARK: - Private

    private func fallbackClusters(notes: [ReadingNote]) -> [[Int]] {
        // 按书分组作为 fallback
        let byBook = Dictionary(grouping: notes.enumerated()) { $0.element.book?.id.uuidString ?? "unknown" }
        return byBook.values.map { $0.map { $0.offset } }.filter { !$0.isEmpty }
    }

    private func kMeans(vectors: [[Double]], k: Int, maxIterations: Int) -> [Int] {
        guard k > 1, !vectors.isEmpty else { return Array(repeating: 0, count: vectors.count) }

        var centroids: [[Double]] = Array(vectors.prefix(k))
        var assignments = Array(repeating: 0, count: vectors.count)

        for _ in 0..<maxIterations {
            var changed = false

            // 分配
            for i in 0..<vectors.count {
                let distances = centroids.enumerated().map { index, centroid in
                    (index, euclideanDistance(vectors[i], centroid))
                }
                let closest = distances.min { $0.1 < $1.1 }?.0 ?? 0
                if assignments[i] != closest {
                    assignments[i] = closest
                    changed = true
                }
            }

            // 更新质心
            for clusterIndex in 0..<k {
                let members = vectors.enumerated().compactMap { assignments[$0.offset] == clusterIndex ? $0.element : nil }
                if members.isEmpty { continue }
                centroids[clusterIndex] = meanVector(members)
            }

            if !changed { break }
        }

        return assignments
    }

    private func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        var sum: Double = 0
        for i in 0..<n {
            let diff = a[i] - b[i]
            sum += diff * diff
        }
        return sum.squareRoot()
    }

    private func meanVector(_ vectors: [[Double]]) -> [Double] {
        guard !vectors.isEmpty else { return [] }
        let dim = vectors[0].count
        var result = Array(repeating: 0.0, count: dim)
        for vector in vectors {
            for i in 0..<dim {
                result[i] += vector[i]
            }
        }
        return result.map { $0 / Double(vectors.count) }
    }

    private func extractKeywords(from text: String, top: Int) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var wordCounts: [String: Int] = [:]
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            let word = String(text[range]).lowercased()
            guard word.count >= 2 else { return true }
            wordCounts[word, default: 0] += 1
            return true
        }

        let stopWords = Set(["的", "了", "和", "是", "在", "有", "我", "都", "个", "与", "也", "对", "为", "能", "很", "可以", "就", "不", "会", "要", "没有", "我们的", "这个", "一个", "通过", "以及", "但是", "因为", "所以", "如果", "需要", "进行", "能够", "我们", "他们", "它们", "the", "a", "an", "is", "are", "was", "were", "and", "or", "but", "of", "to", "in", "for", "on", "with", "as", "by", "that", "this", "it", "from", "at", "be", "have", "has", "had"])

        return wordCounts
            .filter { !stopWords.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(top)
            .map { $0.key }
    }
}
