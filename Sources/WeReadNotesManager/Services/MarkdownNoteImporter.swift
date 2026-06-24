import Foundation

struct MarkdownNoteImporter: NoteImporter {
    var sourceName: String { "markdown" }
    var supportedFileExtensions: [String] { ["md", "markdown"] }

    func canImport(fileURL: URL) -> Bool {
        supportedFileExtensions.contains(fileURL.pathExtension.lowercased())
    }

    func importNotes(from fileURL: URL) throws -> ImportResult {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var books: [ImportedBook] = []
        var notes: [ImportedNote] = []
        var failures: [ImportFailure] = []

        var currentBookTitle: String?
        var currentAuthor: String?
        var currentChapter: String?
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("# ") {
                let rawTitle = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let title = rawTitle
                    .trimmingCharacters(in: CharacterSet(charactersIn: "《》"))
                if !title.isEmpty {
                    currentBookTitle = title
                    currentChapter = nil
                    if !books.contains(where: { $0.title == title }) {
                        books.append(ImportedBook(title: title, author: currentAuthor, coverURL: nil))
                    }
                }
                i += 1
                continue
            }

            if line.hasPrefix("作者：") || line.hasPrefix("作者:") {
                let author = line.replacingOccurrences(of: "作者：", with: "")
                    .replacingOccurrences(of: "作者:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !author.isEmpty {
                    currentAuthor = author
                    if let title = currentBookTitle,
                       let idx = books.firstIndex(where: { $0.title == title }) {
                        let existing = books[idx]
                        books[idx] = ImportedBook(title: existing.title, author: author, coverURL: existing.coverURL)
                    }
                }
                i += 1
                continue
            }

            if line.hasPrefix("## ") {
                currentChapter = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                i += 1
                continue
            }

            if line.hasPrefix("> ") && currentBookTitle != nil {
                let highlight = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !highlight.isEmpty {
                    var userNote: String?
                    var j = i + 1
                    while j < lines.count {
                        let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                        if nextLine.isEmpty { j += 1; continue }
                        if nextLine.hasPrefix("我的想法：") || nextLine.hasPrefix("我的想法:") {
                            let prefix = nextLine.hasPrefix("我的想法：") ? "我的想法：" : "我的想法:"
                            userNote = String(nextLine.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                            if userNote?.isEmpty == true {
                                var noteLines: [String] = []
                                j += 1
                                while j < lines.count {
                                    let nl = lines[j].trimmingCharacters(in: .whitespaces)
                                    if nl.isEmpty || nl.hasPrefix("#") || nl.hasPrefix(">") { break }
                                    noteLines.append(nl)
                                    j += 1
                                }
                                userNote = noteLines.joined(separator: "\n")
                                i = j
                            } else {
                                i = j + 1
                            }
                            break
                        } else if nextLine.hasPrefix(">") || nextLine.hasPrefix("#") {
                            i = j
                            break
                        } else {
                            i = j
                            break
                        }
                    }
                    if j >= lines.count { i = j }

                    notes.append(ImportedNote(
                        bookTitle: currentBookTitle!,
                        author: currentAuthor,
                        chapter: currentChapter,
                        highlight: highlight,
                        userNote: userNote?.isEmpty == true ? nil : userNote,
                        location: nil,
                        createdAt: nil,
                        source: sourceName,
                        sourceID: nil
                    ))
                    continue
                }
            }
            i += 1
        }

        if currentBookTitle == nil {
            failures.append(ImportFailure(
                lineNumber: 1,
                rawText: nil,
                reason: "未找到书名。请确认文件中包含 # 《书名》 格式的一级标题。"
            ))
        }

        return ImportResult(books: books, notes: notes, failures: failures)
    }
}
