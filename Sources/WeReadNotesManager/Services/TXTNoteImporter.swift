import Foundation

struct TXTNoteImporter: NoteImporter {
    var sourceName: String { "txt" }
    var supportedFileExtensions: [String] { ["txt"] }

    func canImport(fileURL: URL) -> Bool {
        supportedFileExtensions.contains(fileURL.pathExtension.lowercased())
    }

    func importNotes(from fileURL: URL) throws -> ImportResult {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let blocks = content.components(separatedBy: "\n\n")

        var books: [ImportedBook] = []
        var notes: [ImportedNote] = []
        var failures: [ImportFailure] = []

        var currentBookTitle: String?
        var currentAuthor: String?
        var currentChapter: String?
        var lineNumber = 0

        for block in blocks {
            let lines = block.components(separatedBy: .newlines).map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
            lineNumber += lines.count + 1

            if lines.isEmpty { continue }

            var blockTitle: String?
            var blockAuthor: String?
            var blockChapter: String?
            var blockHighlight: String?
            var blockNote: String?

            for line in lines {
                if line.hasPrefix("书名：") || line.hasPrefix("书名:") {
                    let prefix = line.hasPrefix("书名：") ? "书名：" : "书名:"
                    blockTitle = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("作者：") || line.hasPrefix("作者:") {
                    let prefix = line.hasPrefix("作者：") ? "作者：" : "作者:"
                    blockAuthor = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("章节：") || line.hasPrefix("章节:") {
                    let prefix = line.hasPrefix("章节：") ? "章节：" : "章节:"
                    blockChapter = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("划线：") || line.hasPrefix("划线:") {
                    let prefix = line.hasPrefix("划线：") ? "划线：" : "划线:"
                    blockHighlight = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("想法：") || line.hasPrefix("想法:") {
                    let prefix = line.hasPrefix("想法：") ? "想法：" : "想法:"
                    blockNote = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                }
            }

            if let title = blockTitle {
                currentBookTitle = title
                currentAuthor = blockAuthor ?? currentAuthor
                if !books.contains(where: { $0.title == title }) {
                    books.append(ImportedBook(title: title, author: currentAuthor, coverURL: nil))
                }
            }
            if let chapter = blockChapter { currentChapter = chapter }

            if let highlight = blockHighlight, !highlight.isEmpty, let bookTitle = currentBookTitle {
                notes.append(ImportedNote(
                    bookTitle: bookTitle,
                    author: currentAuthor ?? blockAuthor,
                    chapter: currentChapter,
                    highlight: highlight,
                    userNote: blockNote,
                    location: nil,
                    createdAt: nil,
                    source: sourceName,
                    sourceID: nil
                ))
            }
        }

        if currentBookTitle == nil {
            failures.append(ImportFailure(
                lineNumber: 1,
                rawText: nil,
                reason: "未找到书名。请确认文件中包含「书名：xxx」格式。"
            ))
        }

        return ImportResult(books: books, notes: notes, failures: failures)
    }
}
