import Foundation
import SwiftUI

// MARK: - 生词本服务
//
// 自动从笔记库提取重要词汇：
// - 高频出现的词（去掉停用词）
// - 用户手动标记的"生词"
// - 跨书反复出现的核心概念
//
// 存储在 JSON：
//   Application Support/树懒书摘/vocabulary.json

struct VocabularyEntry: Codable, Identifiable, Hashable {
    var id: String { word }
    let word: String
    var frequency: Int
    var bookCount: Int
    var firstSeen: Date
    var lastSeen: Date
    var isStarred: Bool  // 用户手动标为生词
    var definition: String?
    var exampleNoteID: UUID?
}

struct VocabularyStore: Codable {
    var entries: [VocabularyEntry] = []

    static var fileURL: URL {
        AppStoragePaths.file("vocabulary.json")
    }

    static func load() -> VocabularyStore {
        guard let data = try? Data(contentsOf: fileURL),
              let store = try? JSONDecoder().decode(VocabularyStore.self, from: data) else {
            return VocabularyStore()
        }
        return store
    }

    static func save(_ store: VocabularyStore) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    mutating func merge(entries: [VocabularyEntry]) {
        for entry in entries {
            if let idx = self.entries.firstIndex(where: { $0.word == entry.word }) {
                self.entries[idx].frequency += entry.frequency
                self.entries[idx].bookCount = max(self.entries[idx].bookCount, entry.bookCount)
                self.entries[idx].lastSeen = entry.lastSeen
            } else {
                self.entries.append(entry)
            }
        }
    }

    mutating func toggleStar(_ word: String) {
        if let idx = entries.firstIndex(where: { $0.word == word }) {
            entries[idx].isStarred.toggle()
        }
    }

    mutating func remove(_ word: String) {
        entries.removeAll { $0.word == word }
    }

    mutating func updateDefinition(_ word: String, definition: String?) {
        if let idx = entries.firstIndex(where: { $0.word == word }) {
            entries[idx].definition = definition
        }
    }
}

// MARK: - 提取器

enum VocabularyExtractor {
    static let stopWords: Set<String> = [
        "的", "了", "在", "是", "我", "有", "和", "就", "不", "人", "都", "一", "一个",
        "上", "也", "很", "到", "说", "要", "去", "你", "会", "着", "没有", "看", "好",
        "自己", "这", "那", "这个", "那个", "这些", "那些", "什么", "怎么", "为什么",
        "因为", "所以", "但是", "如果", "虽然", "然而", "并且", "或者", "而且",
        "the", "a", "an", "of", "in", "to", "is", "are", "was", "were", "be", "been",
        "and", "or", "but", "if", "this", "that", "these", "those", "what", "how"
    ]

    static func extract(from notes: [ReadingNote], minFrequency: Int = 2, minLength: Int = 2) -> [VocabularyEntry] {
        var wordFreq: [String: Int] = [:]
        var wordBooks: [String: Set<UUID>] = [:]
        var wordFirstSeen: [String: Date] = [:]
        var wordLastSeen: [String: Date] = [:]
        var wordExampleNote: [String: UUID] = [:]

        for note in notes {
            let text = note.highlight + " " + (note.userNote ?? "")
            let tokens = tokenize(text: text)

            for token in tokens {
                if token.count < minLength { continue }
                if stopWords.contains(token.lowercased()) { continue }
                if isOnlyPunctuation(token) { continue }

                wordFreq[token, default: 0] += 1
                if let bookID = note.book?.id {
                    wordBooks[token, default: []].insert(bookID)
                }
                let date = note.createdAt ?? note.importedAt
                if wordFirstSeen[token] == nil || (date < (wordFirstSeen[token] ?? .distantFuture)) {
                    wordFirstSeen[token] = date
                    wordExampleNote[token] = note.id
                }
                wordLastSeen[token] = max(wordLastSeen[token] ?? .distantPast, date)
            }
        }

        let now = Date()
        var entries: [VocabularyEntry] = []
        for (word, freq) in wordFreq where freq >= minFrequency {
            entries.append(VocabularyEntry(
                word: word,
                frequency: freq,
                bookCount: wordBooks[word]?.count ?? 0,
                firstSeen: wordFirstSeen[word] ?? now,
                lastSeen: wordLastSeen[word] ?? now,
                isStarred: false,
                definition: nil,
                exampleNoteID: wordExampleNote[word]
            ))
        }

        return entries.sorted { $0.frequency > $1.frequency }
    }

    static func tokenize(text: String) -> [String] {
        // 简单分词：英文按空格，中文按 2-gram + 高频 3-gram
        var tokens: [String] = []

        // 1. 英文单词
        let pattern = "[A-Za-z][A-Za-z]+"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = text as NSString
            let range = NSRange(location: 0, length: nsString.length)
            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let m = match else { return }
                let word = nsString.substring(with: m.range)
                tokens.append(word.lowercased())
            }
        }

        // 2. 中文 2-3 字词
        let nsText = text as NSString
        let length = nsText.length
        var i = 0
        while i < length {
            let char = nsText.character(at: i)
            // 是中文字符（CJK Unified Ideographs）
            if char >= 0x4E00 && char <= 0x9FFF {
                // 2-gram
                if i + 1 < length {
                    let nextChar = nsText.character(at: i + 1)
                    if nextChar >= 0x4E00 && nextChar <= 0x9FFF {
                        let twoGram = nsText.substring(with: NSRange(location: i, length: 2))
                        tokens.append(twoGram)
                    }
                }
                // 3-gram
                if i + 2 < length {
                    let c2 = nsText.character(at: i + 1)
                    let c3 = nsText.character(at: i + 2)
                    if (c2 >= 0x4E00 && c2 <= 0x9FFF) && (c3 >= 0x4E00 && c3 <= 0x9FFF) {
                        let threeGram = nsText.substring(with: NSRange(location: i, length: 3))
                        tokens.append(threeGram)
                    }
                }
            }
            i += 1
        }

        return tokens
    }

    private static func isOnlyPunctuation(_ s: String) -> Bool {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "一-鿿"))
        return s.unicodeScalars.allSatisfy { !allowed.contains($0) }
    }
}

// MARK: - 生词本 UI

struct VocabularyView: View {
    @Environment(\.themePalette) private var palette
    @State private var store: VocabularyStore = .load()
    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var entries: [VocabularyEntry] = []

    enum Filter: String, CaseIterable {
        case all = "全部"
        case starred = "生词"
        case top = "高频"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear { refresh() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "character.book.closed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text("生词本")
                .font(.headline)
            Spacer()
            Picker("", selection: $filter) {
                ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: filter) { _, _ in refresh() }
        }
        .padding(16)
    }

    private var content: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.textTertiary)
                TextField("搜索...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, _ in refresh() }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(palette.surface))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if entries.isEmpty {
                        ContentUnavailableView("暂无生词", systemImage: "character.cursor.ibeam")
                    } else {
                        ForEach(entries) { entry in
                            vocabularyRow(entry)
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private func vocabularyRow(_ entry: VocabularyEntry) -> some View {
        HStack(spacing: 12) {
            // 词
            Text(entry.word)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .frame(minWidth: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if let def = entry.definition, !def.isEmpty {
                    Text(def)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    Label("\(entry.frequency)", systemImage: "number")
                    Label("\(entry.bookCount)", systemImage: "books.vertical")
                }
                .font(.system(size: 10))
                .foregroundStyle(palette.textTertiary)
            }

            Spacer()

            Button {
                toggleStar(entry.word)
            } label: {
                Image(systemName: entry.isStarred ? "star.fill" : "star")
                    .foregroundStyle(entry.isStarred ? palette.warning : palette.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(palette.surface.opacity(0.5)))
    }

    private func refresh() {
        // 加载最新 store
        let current = VocabularyStore.load()
        let entries = current.entries

        var filtered = entries
        switch filter {
        case .all: break
        case .starred: filtered = entries.filter(\.isStarred)
        case .top: filtered = Array(entries.sorted { $0.frequency > $1.frequency }.prefix(50))
        }

        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            filtered = filtered.filter { $0.word.lowercased().contains(lower) }
        }

        self.entries = filtered
    }

    private func toggleStar(_ word: String) {
        var current = VocabularyStore.load()
        current.toggleStar(word)
        VocabularyStore.save(current)
        refresh()
    }
}
