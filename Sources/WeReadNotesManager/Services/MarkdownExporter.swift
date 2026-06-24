import Foundation

struct MarkdownExporter {
    func exportNotes(_ notes: [ReadingNote], bookTitle: String? = nil) -> String {
        let grouped = Dictionary(grouping: notes) { $0.book?.title ?? "未知书籍" }
        var output = ""

        for (title, bookNotes) in grouped.sorted(by: { ($0.key).localizedStandardCompare($1.key) == .orderedAscending }) {
            output += "# 《\(title)》\n\n"
            if let author = bookNotes.first?.book?.author {
                output += "作者：\(author)\n\n"
            }

            let byChapter = Dictionary(grouping: bookNotes) { $0.chapter ?? "未分章" }
            for (chapter, chapterNotes) in byChapter.sorted(by: { ($0.key).localizedStandardCompare($1.key) == .orderedAscending }) {
                if chapter != "未分章" {
                    output += "## \(chapter)\n\n"
                }
                for note in chapterNotes {
                    output += "> \(note.highlight)\n\n"
                    if let userNote = note.userNote, !userNote.isEmpty {
                        output += "我的想法：\n\(userNote)\n\n"
                    }
                    if let location = note.location, !location.isEmpty {
                        output += "位置：\(location)\n"
                    }
                    if let sourceURL = note.sourceURL, !sourceURL.isEmpty {
                        output += "微信读书：\(sourceURL)\n"
                    }
                    output += "收藏：\(note.isFavorite ? "是" : "否")\n"
                    output += "复习次数：\(note.reviewCount)\n"
                    if let lastReviewed = note.lastReviewedAt {
                        output += "上次复习：\(lastReviewed.shortString)\n"
                    }
                    output += "\n"
                }
            }
        }
        return output
    }

    func exportAllBooks(_ books: [Book]) -> String {
        let allNotes = books.flatMap { $0.notes }
        return exportNotes(allNotes)
    }

    func exportObsidianNotes(_ notes: [ReadingNote]) -> String {
        let grouped = Dictionary(grouping: notes) { $0.book?.title ?? "未知书籍" }
        var output = ""

        for (title, bookNotes) in grouped.sorted(by: { ($0.key).localizedStandardCompare($1.key) == .orderedAscending }) {
            let author = bookNotes.first?.book?.author ?? ""
            output += "---\n"
            output += "title: \"\(title)\"\n"
            if !author.isEmpty { output += "author: \"\(author)\"\n" }
            output += "source: 微信读书\n"
            output += "notes: \(bookNotes.count)\n"
            output += "---\n\n"
            output += "# 《\(title)》\n\n"

            let byChapter = Dictionary(grouping: bookNotes) { $0.chapter ?? "未分章" }
            for (chapter, chapterNotes) in byChapter.sorted(by: { ($0.key).localizedStandardCompare($1.key) == .orderedAscending }) {
                output += "## \(chapter)\n\n"
                for note in chapterNotes {
                    output += "- > \(note.highlight)\n"
                    if let userNote = note.userNote, !userNote.isEmpty {
                        output += "  - 想法：\(userNote.replacingOccurrences(of: "\n", with: "\n    "))\n"
                    }
                    if let sourceURL = note.sourceURL, !sourceURL.isEmpty {
                        output += "  - 微信读书：\(sourceURL)\n"
                    }
                    output += "\n"
                }
            }
            output += "\n"
        }

        return output
    }
}
