import Foundation
#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif

// MARK: - 多端同步服务（Tana / Notion / Obsidian）
//
// 三种导出格式：
// - Tana: JSON Supertag 格式（JSONL）
// - Notion: Markdown with frontmatter（Notion API 直接导入）
// - Obsidian: Wiki-style [[双链]] + YAML frontmatter + tag 标签

// MARK: - Obsidian

enum ObsidianExporter {
    /// 把单本书导出为 Obsidian 友好的 Markdown 文件夹。
    /// 每个笔记一个 .md，包含 frontmatter（tags / book / created / source）。
    static func export(notes: [ReadingNote], book: Book) -> String {
        var output = ""

        // 索引文件
        output += "# \(book.title)\n\n"
        if let author = book.author {
            output += "作者：\(author)\n\n"
        }
        output += "笔记数：\(notes.count)\n\n"
        output += "## 目录\n\n"
        for note in notes {
            let safeTitle = String(note.highlight.prefix(30)).replacingOccurrences(of: "\n", with: " ")
            output += "- [[\(book.title)/\(note.id.uuidString)|\(safeTitle)]]\n"
        }
        return output
    }

    /// 单条笔记转 Obsidian Markdown。
    static func exportNote(_ note: ReadingNote) -> String {
        var md = "---\n"
        md += "id: \(note.id.uuidString)\n"
        if let book = note.book {
            md += "book: \"\(escape(book.title))\"\n"
            if let author = book.author {
                md += "author: \"\(escape(author))\"\n"
            }
        }
        if let chapter = note.chapter {
            md += "chapter: \"\(escape(chapter))\"\n"
        }
        let tags = note.tags.map { "#\($0.name)" }.joined(separator: " ")
        if !tags.isEmpty {
            md += "tags: [\(tags)]\n"
        }
        if let createdAt = note.createdAt {
            md += "created: \(ISO8601DateFormatter().string(from: createdAt))\n"
        }
        md += "source: \(note.source)\n"
        md += "---\n\n"

        md += "# \(String(note.highlight.prefix(50)))\n\n"
        md += "> \(note.highlight)\n\n"

        if let userNote = note.userNote, !userNote.isEmpty {
            md += "## 想法\n\n"
            md += "\(userNote)\n\n"
        }

        // 反向链接
        if let book = note.book {
            md += "\n---\n\n返回 [[\(book.title)]]\n"
        }

        return md
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "\\\"")
    }
}

// MARK: - Notion

enum NotionExporter {
    /// 单条笔记 → Notion Markdown 块（Notion API 直接导入格式）。
    static func exportNote(_ note: ReadingNote) -> String {
        var md = "## \(String(note.highlight.prefix(80)))\n\n"
        if let book = note.book {
            md += "**书名**：\(book.title)"
            if let author = book.author {
                md += " · \(author)"
            }
            md += "\n\n"
        }
        if let chapter = note.chapter {
            md += "**章节**：\(chapter)\n\n"
        }

        md += "**原文**\n\n"
        md += "> \(note.highlight)\n\n"

        if let userNote = note.userNote, !userNote.isEmpty {
            md += "**想法**\n\n"
            md += "\(userNote)\n\n"
        }

        if !note.tags.isEmpty {
            md += "**标签**：" + note.tags.map { "`#\($0.name)`" }.joined(separator: " ") + "\n\n"
        }

        md += "---\n\n"
        return md
    }

    /// 整本书导出（带 Notion 数据库属性模拟）。
    static func exportBook(_ book: Book) -> String {
        var md = "# 📚 \(book.title)\n\n"
        if let author = book.author {
            md += "**作者**：\(author)\n\n"
        }
        md += "**笔记数**：\(book.notes.count)\n\n"
        md += "---\n\n"

        // 按章节分组
        let grouped = Dictionary(grouping: book.notes) { note in
            note.chapter ?? "未分章"
        }
        let sortedChapters = grouped.keys.sorted()
        for chapter in sortedChapters {
            md += "## \(chapter)\n\n"
            for note in grouped[chapter] ?? [] {
                md += exportNote(note)
            }
        }
        return md
    }

    /// 生成 Notion API 兼容的 JSON 数据库条目。
    static func notionPageJSON(_ note: ReadingNote) -> [String: Any] {
        var properties: [String: Any] = [
            "Name": ["title": [["text": ["content": String(note.highlight.prefix(80))]]]],
            "Highlight": ["rich_text": [["text": ["content": note.highlight]]]],
            "Book": ["select": ["name": note.book?.title ?? ""]],
            "Chapter": ["rich_text": [["text": ["content": note.chapter ?? ""]]]],
            "IsFavorite": ["checkbox": note.isFavorite],
            "IsReviewed": ["checkbox": note.isReviewed]
        ]
        if let userNote = note.userNote, !userNote.isEmpty {
            properties["UserNote"] = ["rich_text": [["text": ["content": userNote]]]]
        }
        return ["properties": properties]
    }
}

// MARK: - Tana

enum TanaExporter {
    /// 导出为 Tana Supertag JSONL 格式。
    /// 每个 note 一行 JSON，可导入到 Tana Paste 工具。
    static func exportBook(_ book: Book) -> String {
        var jsonl = ""
        // 顶层 node：书
        jsonl += tanaNodeJSON(
            name: book.title,
            superTag: "book",
            children: [
                ["type": "string", "name": "author", "value": book.author ?? ""]
            ] + book.notes.map { note -> [String: Any] in
                [
                    "type": "node",
                    "name": String(note.highlight.prefix(40)),
                    "superTag": "note",
                    "children": [
                        ["type": "string", "name": "highlight", "value": note.highlight],
                        ["type": "string", "name": "chapter", "value": note.chapter ?? ""],
                        ["type": "string", "name": "userNote", "value": note.userNote ?? ""]
                    ]
                ]
            }
        ) + "\n"
        return jsonl
    }

    private static func tanaNodeJSON(
        name: String,
        superTag: String,
        children: [[String: Any]]
    ) -> String {
        let dict: [String: Any] = [
            "type": "node",
            "name": name,
            "superTag": superTag,
            "children": children
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

// MARK: - 多端同步协调器

enum ExternalSyncService {
    enum Destination: String, CaseIterable, Identifiable {
        case obsidian
        case notion
        case tana

        var id: String { rawValue }

        var label: String {
            switch self {
            case .obsidian: return "Obsidian"
            case .notion: return "Notion"
            case .tana: return "Tana"
            }
        }

        var systemImage: String {
            switch self {
            case .obsidian: return "diamond.fill"
            case .notion: return "doc.text"
            case .tana: return "link"
            }
        }

        var fileExtension: String {
            switch self {
            case .obsidian: return "md"
            case .notion: return "md"
            case .tana: return "jsonl"
            }
        }
    }

    /// 导出到指定格式。
    static func export(book: Book, to destination: Destination) -> String {
        switch destination {
        case .obsidian:
            var output = ObsidianExporter.export(notes: book.notes, book: book) + "\n\n---\n\n"
            for note in book.notes {
                output += ObsidianExporter.exportNote(note) + "\n\n"
            }
            return output
        case .notion:
            return NotionExporter.exportBook(book)
        case .tana:
            return TanaExporter.exportBook(book)
        }
    }

    /// 复制到剪贴板。
    static func copyToClipboard(book: Book, destination: Destination) {
        #if canImport(AppKit)
        let content = export(book: book, to: destination)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
        #endif
    }

    /// 保存到文件。
    static func saveToFile(book: Book, destination: Destination) {
        #if canImport(AppKit)
        let content = export(book: book, to: destination)
        let panel = NSSavePanel()
        if let type = UTType(filenameExtension: destination.fileExtension) {
            panel.allowedContentTypes = [type]
        }
        panel.nameFieldStringValue = "\(book.title).\(destination.fileExtension)"
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
        #endif
    }
}