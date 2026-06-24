import Foundation

/// Anki 导出服务
/// 支持导出为 Anki 可导入的 CSV 格式
enum AnkiExporter {
    /// 导出单条笔记为 Anki 卡片
    static func export(note: ReadingNote) -> AnkiCard {
        let front = buildFront(note)
        let back = buildBack(note)
        let tags = buildTags(note)
        return AnkiCard(
            front: front,
            back: back,
            tags: tags,
            bookTitle: note.book?.title ?? "",
            chapter: note.chapter ?? ""
        )
    }
    
    /// 批量导出笔记为 Anki CSV
    static func exportToCSV(notes: [ReadingNote]) -> String {
        let cards = notes.map { export(note: $0) }
        var lines = ["#separator:Tab", "#html:true"]
        
        for card in cards {
            let front = escapeCSV(card.front)
            let back = escapeCSV(card.back)
            let tags = escapeCSV(card.tags.joined(separator: " "))
            lines.append("\(front)\t\(back)\t\(tags)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    private static func buildFront(_ note: ReadingNote) -> String {
        var parts: [String] = []
        
        if let bookTitle = note.book?.title {
            parts.append("<b>\(bookTitle)</b>")
        }
        if let chapter = note.chapter, !chapter.isEmpty {
            parts.append("<i>\(chapter)</i>")
        }
        
        let context = parts.isEmpty ? "" : parts.joined(separator: " · ") + "<br><br>"
        return "\(context)\(note.highlight)"
    }
    
    private static func buildBack(_ note: ReadingNote) -> String {
        var parts: [String] = []
        
        parts.append("<b>原文：</b><br>\(note.highlight)")
        
        if let userNote = note.userNote, !userNote.isEmpty {
            parts.append("<br><br><b>我的想法：</b><br>\(userNote)")
        }
        
        if let location = note.location, !location.isEmpty {
            parts.append("<br><br><b>位置：</b> \(location)")
        }
        
        parts.append("<br><br><b>复习：</b> \(note.reviewCount) 次")
        if let lastReviewed = note.lastReviewedAt {
            parts.append(" · 上次：\(lastReviewed.shortString)")
        }
        
        return parts.joined()
    }
    
    private static func buildTags(_ note: ReadingNote) -> [String] {
        var tags: [String] = []
        
        if let bookTitle = note.book?.title {
            let cleanTitle = bookTitle
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "《", with: "")
                .replacingOccurrences(of: "》", with: "")
            tags.append("book::\(cleanTitle)")
        }
        
        if let chapter = note.chapter, !chapter.isEmpty {
            let cleanChapter = chapter
                .replacingOccurrences(of: " ", with: "_")
            tags.append("chapter::\(cleanChapter)")
        }
        
        if note.isFavorite {
            tags.append("favorite")
        }
        
        if note.isReviewed {
            tags.append("reviewed")
        }
        
        for tag in note.tags {
            tags.append(tag.name.replacingOccurrences(of: " ", with: "_"))
        }
        
        return tags
    }
    
    private static func escapeCSV(_ string: String) -> String {
        string.replacingOccurrences(of: "\t", with: "    ")
              .replacingOccurrences(of: "\n", with: "<br>")
              .replacingOccurrences(of: "\"", with: "\"\"")
    }
}

struct AnkiCard {
    let front: String
    let back: String
    let tags: [String]
    let bookTitle: String
    let chapter: String
}
