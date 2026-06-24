import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case obsidian
    case pdf
    case docx
    case epub
    case anki

    var id: String { rawValue }

    var title: String {
        switch self {
        case .markdown: return "Markdown"
        case .obsidian: return "Obsidian"
        case .pdf: return "PDF"
        case .docx: return "DOCX"
        case .epub: return "Epub"
        case .anki: return "Anki"
        }
    }

    var systemImage: String {
        switch self {
        case .markdown, .obsidian: return "text.alignleft"
        case .pdf: return "doc.richtext"
        case .docx: return "doc.text"
        case .epub: return "book.closed"
        case .anki: return "rectangle.on.rectangle"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown, .obsidian: return "md"
        case .pdf: return "pdf"
        case .docx: return "docx"
        case .epub: return "epub"
        case .anki: return "txt"
        }
    }

    var contentType: UTType {
        switch self {
        case .markdown, .obsidian:
            return .plainText
        case .pdf:
            return .pdf
        case .docx:
            return UTType(filenameExtension: "docx") ?? .data
        case .epub:
            return UTType(filenameExtension: "epub") ?? .data
        case .anki:
            return .plainText
        }
    }
}

enum NoteTemplate: String, CaseIterable, Identifiable {
    case readingReport
    case cleanArchive
    case reviewCards
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readingReport: return "读书报告"
        case .cleanArchive: return "整洁归档"
        case .reviewCards: return "复习卡片"
        case .custom: return "自定义"
        }
    }

    var subtitle: String {
        switch self {
        case .readingReport: return "按书籍、章节组织，适合沉淀成报告"
        case .cleanArchive: return "轻量信息流，适合长期归档"
        case .reviewCards: return "问题式卡片，适合复习和 Anki 前处理"
        case .custom: return "使用自己的占位符模板"
        }
    }

    var notePattern: String {
        switch self {
        case .readingReport:
            return """
            > {{quote}}

            {{thoughtBlock}}{{metaLine}}
            """
        case .cleanArchive:
            return """
            - {{quote}}{{thoughtInline}}{{locationInline}}
            """
        case .reviewCards:
            return """
            **复习问题**：这条书摘想提醒我什么？

            > {{quote}}

            {{thoughtBlock}}{{metaLine}}
            """
        case .custom:
            return "{{quote}}"
        }
    }
}

struct ExportPackage {
    let data: Data
    let contentType: UTType
    let filename: String
}

struct ExportDocumentBuilder {
    var notes: [ReadingNote]
    var format: ExportFormat
    var template: NoteTemplate
    var customTemplate: String
    var baseFilename: String

    func build() throws -> ExportPackage {
        let data: Data
        switch format {
        case .anki:
            let ankiCSV = AnkiExporter.exportToCSV(notes: sortedNotes)
            data = Data(ankiCSV.utf8)
        case .markdown, .obsidian:
            let markdown = renderMarkdown()
            data = Data(markdown.utf8)
        case .pdf:
            let markdown = renderMarkdown()
            data = renderPDF(from: markdown)
        case .docx:
            let markdown = renderMarkdown()
            data = try renderDOCX(from: markdown)
        case .epub:
            let markdown = renderMarkdown()
            data = try renderEpub(from: markdown)
        }
        return ExportPackage(
            data: data,
            contentType: format.contentType,
            filename: "\(baseFilename).\(format.fileExtension)"
        )
    }

    private func renderMarkdown() -> String {
        if format == .obsidian {
            return MarkdownExporter().exportObsidianNotes(sortedNotes)
        }

        let grouped = Dictionary(grouping: sortedNotes) { $0.book?.title ?? "未知书籍" }
        var output = "# 书摘导出\n\n"
        output += "导出时间：\(Date().shortString)\n"
        output += "笔记数量：\(sortedNotes.count)\n\n"

        for (title, bookNotes) in grouped.sorted(by: { $0.key.localizedStandardCompare($1.key) == .orderedAscending }) {
            output += "# 《\(title)》\n\n"
            if let author = bookNotes.first?.book?.author, !author.isEmpty {
                output += "作者：\(author)\n\n"
            }

            let byChapter = Dictionary(grouping: bookNotes) { normalizedChapter($0.chapter) }
            for (chapter, chapterNotes) in byChapter.sorted(by: { $0.key.localizedStandardCompare($1.key) == .orderedAscending }) {
                if chapter != "未分章" {
                    output += "## \(chapter)\n\n"
                }
                for note in chapterNotes {
                    output += renderNote(note)
                    if !output.hasSuffix("\n\n") {
                        output += "\n\n"
                    }
                }
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private func renderNote(_ note: ReadingNote) -> String {
        let pattern = template == .custom && !customTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? customTemplate
            : template.notePattern

        let thought = note.userNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let location = note.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let chapter = normalizedChapter(note.chapter)
        let date = (note.createdAt ?? note.importedAt).shortString

        let replacements: [String: String] = [
            "book": note.book?.title ?? "未知书籍",
            "author": note.book?.author ?? "",
            "chapter": chapter,
            "quote": note.highlight.trimmingCharacters(in: .whitespacesAndNewlines),
            "thought": thought,
            "thoughtBlock": thought.isEmpty ? "" : "我的想法：\n\(thought)\n\n",
            "thoughtInline": thought.isEmpty ? "" : "｜想法：\(thought)",
            "location": location,
            "locationInline": location.isEmpty ? "" : "（\(location)）",
            "date": date,
            "favorite": note.isFavorite ? "是" : "否",
            "reviewCount": "\(note.reviewCount)",
            "metaLine": metaLine(for: note)
        ]

        return replacements.reduce(pattern) { result, pair in
            result.replacingOccurrences(of: "{{\(pair.key)}}", with: pair.value)
        }
    }

    private func metaLine(for note: ReadingNote) -> String {
        var parts: [String] = []
        if let location = note.location, !location.isEmpty { parts.append("位置：\(location)") }
        parts.append("收藏：\(note.isFavorite ? "是" : "否")")
        parts.append("复习：\(note.reviewCount) 次")
        return parts.joined(separator: " · ")
    }

    private var sortedNotes: [ReadingNote] {
        notes.filter { !$0.isDeleted }.sorted {
            let left = "\($0.book?.title ?? "")|\($0.chapter ?? "")|\($0.location ?? "")|\($0.createdAt ?? $0.importedAt)"
            let right = "\($1.book?.title ?? "")|\($1.chapter ?? "")|\($1.location ?? "")|\($1.createdAt ?? $1.importedAt)"
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }

    private func normalizedChapter(_ chapter: String?) -> String {
        guard let chapter, !chapter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "未分章"
        }
        return chapter
    }
}

private extension ExportDocumentBuilder {
    func renderPDF(from markdown: String) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 54
        let textRect = pageRect.insetBy(dx: margin, dy: margin)
        let attributed = NSAttributedString(
            string: plainText(from: markdown),
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: pdfParagraphStyle
            ]
        )

        let storage = NSTextStorage(attributedString: attributed)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }

        var glyphIndex = 0
        while glyphIndex < layout.numberOfGlyphs {
            let container = NSTextContainer(size: textRect.size)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)

            context.beginPDFPage([kCGPDFContextMediaBox as String: pageRect] as CFDictionary)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

            let glyphRange = layout.glyphRange(for: container)
            layout.drawBackground(forGlyphRange: glyphRange, at: textRect.origin)
            layout.drawGlyphs(forGlyphRange: glyphRange, at: textRect.origin)

            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
            glyphIndex = NSMaxRange(glyphRange)
        }
        context.closePDF()
        return data as Data
    }

    var pdfParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        style.paragraphSpacing = 8
        return style
    }

    func renderDOCX(from markdown: String) throws -> Data {
        let temp = try temporaryPackageDirectory(prefix: "docx")
        defer { try? FileManager.default.removeItem(at: temp) }

        let word = temp.appendingPathComponent("word", isDirectory: true)
        let rels = temp.appendingPathComponent("_rels", isDirectory: true)
        try FileManager.default.createDirectory(at: word, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rels, withIntermediateDirectories: true)

        try xml("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """, to: temp.appendingPathComponent("[Content_Types].xml"))

        try xml("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """, to: rels.appendingPathComponent(".rels"))

        let paragraphs = plainText(from: markdown)
            .components(separatedBy: .newlines)
            .map { line in
                "<w:p><w:r><w:t xml:space=\"preserve\">\(line.xmlEscaped)</w:t></w:r></w:p>"
            }
            .joined(separator: "\n")

        try xml("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            \(paragraphs)
            <w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
          </w:body>
        </w:document>
        """, to: word.appendingPathComponent("document.xml"))

        return try zip(directory: temp, fileExtension: "docx")
    }

    func renderEpub(from markdown: String) throws -> Data {
        let temp = try temporaryPackageDirectory(prefix: "epub")
        defer { try? FileManager.default.removeItem(at: temp) }

        try "application/epub+zip".write(to: temp.appendingPathComponent("mimetype"), atomically: true, encoding: .utf8)

        let metaInf = temp.appendingPathComponent("META-INF", isDirectory: true)
        let ops = temp.appendingPathComponent("OEBPS", isDirectory: true)
        try FileManager.default.createDirectory(at: metaInf, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ops, withIntermediateDirectories: true)

        try xml("""
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """, to: metaInf.appendingPathComponent("container.xml"))

        let body = plainText(from: markdown)
            .components(separatedBy: "\n\n")
            .map { "<p>\($0.xmlEscaped.replacingOccurrences(of: "\n", with: "<br/>"))</p>" }
            .joined(separator: "\n")

        try xml("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="zh-CN">
        <head><title>书摘导出</title><meta charset="utf-8"/></head>
        <body>
        \(body)
        </body>
        </html>
        """, to: ops.appendingPathComponent("notes.xhtml"))

        try xml("""
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">urn:uuid:\(UUID().uuidString)</dc:identifier>
            <dc:title>书摘导出</dc:title>
            <dc:language>zh-CN</dc:language>
          </metadata>
          <manifest>
            <item id="notes" href="notes.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="notes"/>
          </spine>
        </package>
        """, to: ops.appendingPathComponent("content.opf"))

        return try zip(directory: temp, fileExtension: "epub")
    }

    func plainText(from markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"(?m)^#{1,6}\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^>\s*"#, with: "“", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)\*\*(.*?)\*\*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^-\s*"#, with: "• ", options: .regularExpression)
    }

    func temporaryPackageDirectory(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("weread-\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func xml(_ string: String, to url: URL) throws {
        try string.write(to: url, atomically: true, encoding: .utf8)
    }

    func zip(directory: URL, fileExtension: String) throws -> Data {
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("weread-export-\(UUID().uuidString).\(fileExtension)")
        defer { try? FileManager.default.removeItem(at: out) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-X", "-r", out.path, "."]
        process.currentDirectoryURL = directory
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExportBuildError.archiveFailed
        }
        return try Data(contentsOf: out)
    }
}

enum ExportBuildError: LocalizedError {
    case archiveFailed

    var errorDescription: String? {
        switch self {
        case .archiveFailed:
            return "生成压缩文档失败。"
        }
    }
}

struct BinaryExportDocument: FileDocument {
    static var readableContentTypes: [UTType] = [
        .data,
        .plainText,
        .pdf,
        UTType(filenameExtension: "docx") ?? .data,
        UTType(filenameExtension: "epub") ?? .data,
        UTType(filenameExtension: "txt") ?? .data
    ]

    var data: Data
    var type: UTType

    init(data: Data = Data(), type: UTType = .data) {
        self.data = data
        self.type = type
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        type = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
