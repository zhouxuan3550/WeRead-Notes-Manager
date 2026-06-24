import Foundation

struct ThemeCluster: Identifiable {
    let id: String
    let title: String
    let count: Int
    let books: [Book]
    let notes: [ReadingNote]
}

enum ReadingInsightService {
    private static let stopWords: Set<String> = [
        "一个", "一种", "这个", "那个", "我们", "他们", "你们", "自己", "没有", "不是", "因为", "所以", "但是", "如果",
        "可以", "需要", "可能", "已经", "就是", "还是", "或者", "以及", "通过", "关于", "进行", "这种", "这些", "那些",
        "什么", "怎么", "为什么", "如何", "的", "了", "在", "是", "有", "也", "都", "就", "会", "能", "要", "来", "去",
        "第一", "第二", "第三", "第四", "第五", "第六", "第七", "第八", "第九", "第十",
        "之一", "之一", "一些", "一点", "一下", "一样", "一般", "一样", "一起", "一直",
        "已经", "正在", "将要", "可能", "应该", "可以", "能够", "必须", "需要",
        "the", "and", "for", "with", "that", "this", "from", "into", "your", "you", "are", "not", "is", "it"
    ]

    /// 关键词提取的正则：英文/数字 token 或 2-6 字中文。
    /// 预编译一次，避免每条笔记每次匹配都重新构造 NSRegularExpression。
    /// 注意：不能用 raw string（`#""#`），否则 `\u{...}` 转义不会被 Swift 处理，
    /// NSRegularExpression 收到的是字面字符序列 `\u{4e00}` 而非 Unicode 范围。
    private static let keywordRegex: NSRegularExpression = {
        let pattern = "[A-Za-z][A-Za-z0-9_\\-]{2,}|[\u{4e00}-\u{9fff}]{2,6}"
        // 模式硬编码，运行时不应失败
        return try! NSRegularExpression(pattern: pattern)
    }()

    static func themeClusters(from books: [Book]) -> [ThemeCluster] {
        themeClusters(fromNotes: books.flatMap { $0.notes })
    }

    /// 直接接受笔记列表的重载，便于单元测试（无需走 SwiftData 关系加载）。
    static func themeClusters(fromNotes notes: [ReadingNote]) -> [ThemeCluster] {
        var notesByKeyword: [String: [ReadingNote]] = [:]
        var keywordScores: [String: Int] = [:]
        
        for note in notes {
            // 主要从 highlight 和 userNote 中提取关键词
            let textToProcess = "\(note.highlight) \(note.userNote ?? "")"
            for keyword in keywords(in: textToProcess) {
                notesByKeyword[keyword, default: []].append(note)
                // 给来自 userNote 的关键词更高权重
                let score = note.userNote != nil ? 3 : 1
                keywordScores[keyword, default: 0] += score
            }
        }

        return notesByKeyword
            .map { keyword, notes in
                let uniqueBooks = Dictionary(grouping: notes.compactMap { $0.book }, by: { $0.id })
                    .compactMap { $0.value.first }
                    .sorted { $0.notes.count > $1.notes.count }
                
                // 综合评分：笔记数量 + 关键词分数
                let score = notes.count * 2 + (keywordScores[keyword] ?? 0)
                
                return (keyword, notes, uniqueBooks, score)
            }
            .filter { $0.1.count >= 3 } // 至少 3 条笔记才算主题
            .sorted { lhs, rhs in
                if lhs.3 == rhs.3 { return lhs.0.count > rhs.0.count } // 词长优先
                return lhs.3 > rhs.3
            }
            .prefix(20)
            .map { keyword, notes, books, _ in
                return ThemeCluster(id: keyword, title: keyword, count: notes.count, books: books, notes: notes)
            }
    }

    static func keywords(in text: String) -> [String] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = keywordRegex.matches(in: text, range: range)
        var result: Set<String> = []
        var allCandidates: [String] = []

        // 先收集所有可能的词
        for match in matches {
            guard let swiftRange = Range(match.range, in: text) else { continue }
            let run = String(text[swiftRange])
            let scalars = Array(run)
            let maxLen = min(6, scalars.count)
            for length in 3...maxLen { // 优先 3 个字以上的词
                for i in 0...(scalars.count - length) {
                    let substring = String(scalars[i..<(i + length)]).lowercased()
                    if !stopWords.contains(substring) {
                        allCandidates.append(substring)
                    }
                }
            }
        }

        // 统计词频
        var frequency: [String: Int] = [:]
        for candidate in allCandidates {
            frequency[candidate, default: 0] += 1
        }

        // 优先保留更长、出现次数更多的词
        let sortedCandidates = frequency
            .filter { $0.value >= 1 } // 至少出现 1 次
            .sorted { lhs, rhs in
                if lhs.key.count == rhs.key.count {
                    return lhs.value > rhs.value
                }
                return lhs.key.count > rhs.key.count
            }
            .map { $0.key }
            .prefix(20)

        // 去重：如果一个词包含另一个词，只保留长的
        var finalResult: Set<String> = []
        for candidate in sortedCandidates {
            let isSubstring = finalResult.contains { $0.contains(candidate) || candidate.contains($0) }
            if !isSubstring {
                finalResult.insert(candidate)
            }
        }

        return Array(finalResult)
    }

    static func bookReport(for book: Book) -> BookReadingReport {
        let notes = book.notes
        let clusters = themeClusters(from: [book]).prefix(8)
        let chapterGroups = Dictionary(grouping: notes) { $0.chapter?.isEmpty == false ? $0.chapter! : "未分章" }
        let topChapters = chapterGroups
            .map { (title: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }

        return BookReadingReport(
            book: book,
            noteCount: notes.count,
            thoughtCount: notes.filter { $0.userNote?.isEmpty == false || $0.noteKind == "review" }.count,
            favoriteCount: notes.filter { $0.isFavorite }.count,
            themes: clusters.map(\.title),
            topChapters: topChapters,
            featuredNotes: Array(notes.sorted { score($0) > score($1) }.prefix(8))
        )
    }

    private static func score(_ note: ReadingNote) -> Int {
        var value = 0
        if note.isFavorite { value += 100 }
        if note.userNote?.isEmpty == false { value += 40 }
        value += min(note.highlight.count / 20, 30)
        return value
    }
}

struct BookReadingReport {
    let book: Book
    let noteCount: Int
    let thoughtCount: Int
    let favoriteCount: Int
    let themes: [String]
    let topChapters: [(title: String, count: Int)]
    let featuredNotes: [ReadingNote]
}
