import Foundation

// MARK: - 笔记双链索引
//
// 用 JSON 文件存储 [[双链]] 关系，避免修改 SwiftData 模型。
// 格式：
//   {
//     "forward": { "noteID": ["targetNoteID", ...] },
//     "backward": { "noteID": ["sourceNoteID", ...] }
//   }
//
// [[xxx]] 解析规则：
// - 提取 [[标题]] 或 [[标题|显示文本]]
// - 在所有笔记里查匹配标题（精确 > 前缀 > 模糊）
// - 失败则在 [[xxx]] 旁加红色下划线

struct NoteLinkIndex: Codable {
    var forward: [String: [String]] = [:]
    var backward: [String: [String]] = [:]

    static var fileURL: URL {
        AppStoragePaths.file("link-index.json")
    }

    static func load() -> NoteLinkIndex {
        guard let data = try? Data(contentsOf: fileURL),
              let idx = try? JSONDecoder().decode(NoteLinkIndex.self, from: data) else {
            return NoteLinkIndex()
        }
        return idx
    }

    static func save(_ index: NoteLinkIndex) {
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    mutating func rebuild(from notes: [ReadingNote]) {
        forward.removeAll()
        backward.removeAll()

        for note in notes {
            let links = Self.extractLinks(from: note)
            let sourceKey = note.id.uuidString
            for target in links {
                guard let targetNote = Self.findNote(byTitle: target, in: notes),
                      targetNote.id != note.id else { continue }
                let targetKey = targetNote.id.uuidString
                if !forward[sourceKey, default: []].contains(targetKey) {
                    forward[sourceKey, default: []].append(targetKey)
                }
                if !backward[targetKey, default: []].contains(sourceKey) {
                    backward[targetKey, default: []].append(sourceKey)
                }
            }
        }

        Self.save(self)
    }

    func outgoingLinks(of noteID: UUID) -> [UUID] {
        (forward[noteID.uuidString] ?? []).compactMap(UUID.init(uuidString:))
    }

    func incomingLinks(of noteID: UUID) -> [UUID] {
        (backward[noteID.uuidString] ?? []).compactMap(UUID.init(uuidString:))
    }

    // MARK: - 解析 [[]]

    static func extractLinks(from note: ReadingNote) -> [String] {
        let combined = (note.highlight + "\n" + (note.userNote ?? ""))
        return extractLinks(from: combined)
    }

    static func extractLinks(from text: String) -> [String] {
        var results: [String] = []
        // 匹配 [[...]]
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let openRange = text.range(of: "[[", range: searchStart..<text.endIndex) {
            guard let closeRange = text.range(of: "]]", range: openRange.upperBound..<text.endIndex) else {
                break
            }
            let inner = String(text[openRange.upperBound..<closeRange.lowerBound])
            // [[title|alias]] 或 [[title]]
            let title = inner.components(separatedBy: "|").first ?? inner
            results.append(title.trimmingCharacters(in: .whitespacesAndNewlines))
            searchStart = closeRange.upperBound
        }
        return Array(Set(results))
    }

    static func findNote(byTitle title: String, in notes: [ReadingNote]) -> ReadingNote? {
        // 1. 精确匹配
        if let exact = notes.first(where: { matchesTitle($0.highlight, title) || matchesTitle($0.userNote ?? "", title) }) {
            return exact
        }
        // 2. 标题包含 title
        if let partial = notes.first(where: { ($0.book?.title ?? "").contains(title) || $0.highlight.contains(title) }) {
            return partial
        }
        return nil
    }

    private static func matchesTitle(_ text: String, _ title: String) -> Bool {
        text.localizedCaseInsensitiveContains(title)
    }
}

// MARK: - 双链解析器（UI 用）

enum NoteLinkParser {
    /// 解析文本中的 [[双链]]，返回带链接注释的 AttributedString
    static func render(_ text: String, notes: [ReadingNote], palette: ThemePalette) -> AttributedString {
        var attr = AttributedString(text)

        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let openRange = text.range(of: "[[", range: searchStart..<text.endIndex) {
            guard let closeRange = text.range(of: "]]", range: openRange.upperBound..<text.endIndex) else {
                break
            }

            let inner = String(text[openRange.upperBound..<closeRange.lowerBound])
            let parts = inner.components(separatedBy: "|")
            let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let displayText = parts.count > 1 ? parts[1] : title

            // 计算在 attr 里的位置
            let lowerOffset = text.distance(from: text.startIndex, to: openRange.lowerBound)
            let upperOffset = text.distance(from: text.startIndex, to: closeRange.upperBound)
            let chars = attr.characters
            if lowerOffset < chars.count, upperOffset <= chars.count,
               let attrStart = chars.index(chars.startIndex, offsetBy: lowerOffset, limitedBy: chars.endIndex),
               let attrEnd = chars.index(chars.startIndex, offsetBy: upperOffset, limitedBy: chars.endIndex) {
                let range = attrStart..<attrEnd
                // 找到对应笔记
                if let target = NoteLinkIndex.findNote(byTitle: title, in: notes) {
                    // 已存在的链接：蓝色下划线
                    attr[range].foregroundColor = palette.accent
                    attr[range].underlineStyle = .single
                    attr[range].link = URL(string: "weread://note/\(target.id.uuidString)")
                } else {
                    // 不存在的链接：红色虚线（提示未找到）
                    attr[range].foregroundColor = palette.error
                    attr[range].underlineStyle = .single
                }
            }

            searchStart = closeRange.upperBound
        }

        return attr
    }
}

// MARK: - 双链建议器

enum NoteLinkSuggester {
    /// 输入前缀，返回匹配的笔记建议
    static func suggest(prefix: String, notes: [ReadingNote], limit: Int = 8) -> [NoteLinkSuggestion] {
        guard !prefix.isEmpty else { return [] }
        let lower = prefix.lowercased()

        var suggestions: [NoteLinkSuggestion] = []
        for note in notes {
            let bookTitle = note.book?.title ?? ""
            let snippet = String(note.highlight.prefix(40))

            // 书名命中
            if bookTitle.lowercased().contains(lower) {
                suggestions.append(NoteLinkSuggestion(
                    noteID: note.id,
                    display: bookTitle,
                    subtitle: "\(bookTitle) · \(note.chapter ?? "未分章")",
                    kind: .book
                ))
                continue
            }

            // 笔记内容命中
            if note.highlight.lowercased().contains(lower) {
                suggestions.append(NoteLinkSuggestion(
                    noteID: note.id,
                    display: snippet,
                    subtitle: bookTitle,
                    kind: .note
                ))
            }

            if suggestions.count >= limit { break }
        }

        return suggestions
    }
}

struct NoteLinkSuggestion: Identifiable, Hashable {
    let noteID: UUID
    var id: UUID { noteID }
    let display: String
    let subtitle: String
    let kind: Kind

    enum Kind {
        case book, note
    }
}
