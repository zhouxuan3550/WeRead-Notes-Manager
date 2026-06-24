import Foundation

struct WeReadSkillImporter: NoteImporter {
    var sourceName: String { "weread_skill" }
    var supportedFileExtensions: [String] { ["json", "txt"] }

    func canImport(fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        guard supportedFileExtensions.contains(ext) else { return false }
        if ext == "json" { return true }

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return false
        }
        return looksLikeWeReadText(content)
    }

    func importNotes(from fileURL: URL) throws -> ImportResult {
        let ext = fileURL.pathExtension.lowercased()
        if ext == "json" {
            return try importJSON(from: fileURL)
        }
        return try importText(from: fileURL)
    }
}

private extension WeReadSkillImporter {
    struct SkillPayload: Decodable {
        let notes: [SkillNote]?
        let books: [SkillBook]?
    }

    struct SkillBook: Decodable {
        let title: String?
        let bookTitle: String?
        let name: String?
        let author: String?
        let coverURL: String?
    }

    struct SkillNote: Decodable {
        let id: String?
        let noteID: String?
        let sourceID: String?
        let bookTitle: String?
        let title: String?
        let book: String?
        let author: String?
        let coverURL: String?
        let chapter: String?
        let highlight: String?
        let text: String?
        let content: String?
        let note: String?
        let userNote: String?
        let location: String?
        let createdAt: String?
        let updatedAt: String?
    }

    func importJSON(from fileURL: URL) throws -> ImportResult {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()

        let skillNotes: [SkillNote]
        let payloadBooks: [SkillBook]
        if let notes = try? decoder.decode([SkillNote].self, from: data) {
            skillNotes = notes
            payloadBooks = []
        } else if let payload = try? decoder.decode(SkillPayload.self, from: data) {
            skillNotes = payload.notes ?? []
            payloadBooks = payload.books ?? []
        } else if let single = try? decoder.decode(SkillNote.self, from: data) {
            skillNotes = [single]
            payloadBooks = []
        } else {
            throw ImportError.parseFailed("无法识别微信读书 Skill JSON。请确认文件包含 notes 数组或笔记对象。")
        }

        var booksByKey: [String: ImportedBook] = [:]
        var notes: [ImportedNote] = []
        var failures: [ImportFailure] = []

        for book in payloadBooks {
            if let importedBook = importedBook(from: book) {
                booksByKey[bookKey(title: importedBook.title, author: importedBook.author)] = importedBook
            }
        }

        for (index, skillNote) in skillNotes.enumerated() {
            guard let importedNote = importedNote(from: skillNote) else {
                failures.append(ImportFailure(
                    lineNumber: index + 1,
                    rawText: nil,
                    reason: "缺少书名或划线内容"
                ))
                continue
            }
            notes.append(importedNote)
            let book = ImportedBook(
                title: importedNote.bookTitle,
                author: importedNote.author,
                coverURL: skillNote.coverURL
            )
            booksByKey[bookKey(title: book.title, author: book.author)] = book
        }

        return ImportResult(books: Array(booksByKey.values), notes: notes, failures: failures)
    }

    func importText(from fileURL: URL) throws -> ImportResult {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var bookTitle = parseMetaValue(named: ["书名", "书籍", "标题"], in: lines)
        if bookTitle == nil {
            bookTitle = firstBookTitle(in: lines)
        }
        let author = parseMetaValue(named: ["作者"], in: lines)

        guard let title = bookTitle, !title.isEmpty else {
            return ImportResult(
                books: [],
                notes: [],
                failures: [ImportFailure(
                    lineNumber: 1,
                    rawText: nil,
                    reason: "未找到书名。请确认微信读书文本包含「书名：xxx」或《书名》。"
                )]
            )
        }

        var notes: [ImportedNote] = []
        var failures: [ImportFailure] = []
        var currentChapter: String?
        var pendingHighlight: PendingText?
        var pendingUserNote: PendingText?
        var pendingLocation: String?

        func flushPending() {
            guard let highlight = pendingHighlight?.text.trimmedNonEmpty else {
                pendingHighlight = nil
                pendingUserNote = nil
                pendingLocation = nil
                return
            }

            notes.append(ImportedNote(
                bookTitle: title,
                author: author,
                chapter: currentChapter,
                highlight: highlight,
                userNote: pendingUserNote?.text.trimmedNonEmpty,
                location: pendingLocation,
                createdAt: nil,
                source: sourceName,
                sourceID: nil
            ))
            pendingHighlight = nil
            pendingUserNote = nil
            pendingLocation = nil
        }

        for (offset, rawLine) in lines.enumerated() {
            let lineNumber = offset + 1
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            if isMetadataLine(line) || isNoiseLine(line) {
                continue
            }

            if let chapter = parseChapterLine(line) {
                flushPending()
                currentChapter = chapter
                continue
            }

            if let location = parseLocationLine(line) {
                pendingLocation = location
                continue
            }

            if let highlight = parseHighlightLine(line) {
                flushPending()
                pendingHighlight = PendingText(text: highlight, startedAt: lineNumber)
                continue
            }

            if let userNote = parseUserNoteLine(line) {
                pendingUserNote = PendingText(text: userNote, startedAt: lineNumber)
                continue
            }

            if pendingUserNote != nil {
                pendingUserNote?.append(line)
            } else if pendingHighlight != nil {
                pendingHighlight?.append(line)
            } else if currentChapter == nil {
                currentChapter = line
            } else {
                failures.append(ImportFailure(
                    lineNumber: lineNumber,
                    rawText: line,
                    reason: "未能识别为章节、划线或想法"
                ))
            }
        }

        flushPending()

        let books = [ImportedBook(title: title, author: author, coverURL: nil)]
        if notes.isEmpty && failures.isEmpty {
            failures.append(ImportFailure(
                lineNumber: 1,
                rawText: nil,
                reason: "未找到微信读书划线。请确认文本中包含以 >>、划线：或原文：开头的内容。"
            ))
        }
        return ImportResult(books: books, notes: notes, failures: failures)
    }

    func importedBook(from book: SkillBook) -> ImportedBook? {
        guard let title = firstNonEmpty(book.title, book.bookTitle, book.name) else {
            return nil
        }
        return ImportedBook(title: title, author: book.author?.trimmedNonEmpty, coverURL: book.coverURL?.trimmedNonEmpty)
    }

    func importedNote(from note: SkillNote) -> ImportedNote? {
        guard let title = firstNonEmpty(note.bookTitle, note.title, note.book),
              let highlight = firstNonEmpty(note.highlight, note.text, note.content) else {
            return nil
        }
        return ImportedNote(
            bookTitle: title,
            author: note.author?.trimmedNonEmpty,
            chapter: note.chapter?.trimmedNonEmpty,
            highlight: highlight,
            userNote: firstNonEmpty(note.userNote, note.note),
            location: note.location?.trimmedNonEmpty,
            createdAt: parseDate(note.createdAt) ?? parseDate(note.updatedAt),
            source: sourceName,
            sourceID: firstNonEmpty(note.sourceID, note.noteID, note.id)
        )
    }

    func looksLikeWeReadText(_ content: String) -> Bool {
        let lines = content.components(separatedBy: .newlines)
        let joined = content.prefix(4000)
        return joined.contains("微信读书")
            || joined.contains("◆")
            || joined.contains(">>")
            || joined.contains("书名：")
            || lines.contains(where: { parseHighlightLine($0.trimmingCharacters(in: .whitespacesAndNewlines)) != nil })
    }

    func parseMetaValue(named names: [String], in lines: [String]) -> String? {
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            for name in names {
                for separator in ["：", ":"] {
                    let prefix = "\(name)\(separator)"
                    if line.hasPrefix(prefix) {
                        return String(line.dropFirst(prefix.count)).trimmingBookMarks.trimmedNonEmpty
                    }
                }
            }
        }
        return nil
    }

    func firstBookTitle(in lines: [String]) -> String? {
        for rawLine in lines.prefix(12) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if let title = titleBetweenBookMarks(in: line) {
                return title
            }
        }
        return nil
    }

    func titleBetweenBookMarks(in line: String) -> String? {
        guard let start = line.firstIndex(of: "《"),
              let end = line[start...].firstIndex(of: "》"),
              start < end else {
            return nil
        }
        let titleStart = line.index(after: start)
        return String(line[titleStart..<end]).trimmedNonEmpty
    }

    func isMetadataLine(_ line: String) -> Bool {
        let keys = ["书名", "书籍", "标题", "作者", "笔记数量", "导出时间", "来自", "微信读书"]
        return keys.contains { key in
            line.hasPrefix("\(key)：") || line.hasPrefix("\(key):")
        }
    }

    func isNoiseLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: "-_—= "))
        return trimmed.isEmpty
    }

    func parseChapterLine(_ line: String) -> String? {
        if line.hasPrefix("◆") {
            return String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
        }
        if line.hasPrefix("章节：") {
            return String(line.dropFirst("章节：".count)).trimmedNonEmpty
        }
        if line.hasPrefix("章节:") {
            return String(line.dropFirst("章节:".count)).trimmedNonEmpty
        }
        return nil
    }

    func parseHighlightLine(_ line: String) -> String? {
        let prefixes = [">>", "划线：", "划线:", "原文：", "原文:", "书摘：", "书摘:"]
        for prefix in prefixes where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    func parseUserNoteLine(_ line: String) -> String? {
        let prefixes = ["--", "想法：", "想法:", "我的想法：", "我的想法:", "笔记：", "笔记:"]
        for prefix in prefixes where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    func parseLocationLine(_ line: String) -> String? {
        let prefixes = ["位置：", "位置:", "页码：", "页码:"]
        for prefix in prefixes where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count)).trimmedNonEmpty
        }
        if line.hasPrefix("第") && (line.contains("页") || line.contains("章")) {
            return line
        }
        return nil
    }

    func parseDate(_ rawValue: String?) -> Date? {
        guard let value = rawValue?.trimmedNonEmpty else { return nil }
        return ChineseDateParser.parse(value)
    }

    func firstNonEmpty(_ values: String?...) -> String? {
        values.compactMap { $0?.trimmedNonEmpty }.first
    }

    func bookKey(title: String, author: String?) -> String {
        "\(title.normalizedForHash())|\((author ?? "").normalizedForHash())"
    }

    struct PendingText {
        var text: String
        let startedAt: Int

        mutating func append(_ line: String) {
            if text.isEmpty {
                text = line
            } else {
                text += "\n\(line)"
            }
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var trimmingBookMarks: String {
        trimmingCharacters(in: CharacterSet(charactersIn: "《》"))
    }
}
