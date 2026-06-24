import XCTest
@testable import WeReadNotesManager

final class MarkdownExporterTests: XCTestCase {
    private let exporter = MarkdownExporter()

    func testExportNotes_GroupsByBookAndChapter() {
        let bookA = makeBook(title: "A书", author: "作者甲")
        let bookB = makeBook(title: "B书", author: "作者乙")
        let notes: [ReadingNote] = [
            makeNote(book: bookA, chapter: "第一章", highlight: "划线1"),
            makeNote(book: bookA, chapter: "第二章", highlight: "划线2"),
            makeNote(book: bookB, chapter: nil, highlight: "划线3")
        ]

        let output = exporter.exportNotes(notes)
        XCTAssertTrue(output.contains("# 《A书》"))
        XCTAssertTrue(output.contains("# 《B书》"))
        XCTAssertTrue(output.contains("## 第一章"))
        XCTAssertTrue(output.contains("## 第二章"))
        // "未分章" 在 MarkdownExporter 中不显式输出 `## ` 头（避免噪音），
        // 但其下的笔记仍然按顺序输出。
        XCTAssertTrue(output.contains("> 划线3"))
        XCTAssertTrue(output.contains("作者：作者甲"))
        XCTAssertTrue(output.contains("作者：作者乙"))
    }

    func testExportNotes_IncludesUserNoteAndMetadata() {
        let book = makeBook(title: "测试书", author: nil)
        let note = makeNote(
            book: book,
            chapter: "第一章",
            highlight: "重点划线",
            userNote: "我的想法",
            location: "第 32 页",
            sourceURL: "weread://reading?bId=123",
            isFavorite: true,
            reviewCount: 3
        )

        let output = exporter.exportNotes([note])
        XCTAssertTrue(output.contains("> 重点划线"))
        XCTAssertTrue(output.contains("我的想法：\n我的想法"))
        XCTAssertTrue(output.contains("位置：第 32 页"))
        XCTAssertTrue(output.contains("微信读书：weread://reading?bId=123"))
        XCTAssertTrue(output.contains("收藏：是"))
        XCTAssertTrue(output.contains("复习次数：3"))
    }

    func testExportObsidianNotes_GeneratesFrontMatter() {
        let book = makeBook(title: "测试书", author: "作者")
        let note = makeNote(book: book, chapter: nil, highlight: "划线")

        let output = exporter.exportObsidianNotes([note])
        XCTAssertTrue(output.contains("---"))
        XCTAssertTrue(output.contains("title: \"测试书\""))
        XCTAssertTrue(output.contains("author: \"作者\""))
        XCTAssertTrue(output.contains("source: 微信读书"))
    }

    func testExportAllBooks_ConcatenatesBooks() {
        let book = makeBook(title: "测试书", author: "作者")
        book.notes = [
            makeNote(book: book, chapter: "第一章", highlight: "n1"),
            makeNote(book: book, chapter: "第二章", highlight: "n2")
        ]

        let output = exporter.exportAllBooks([book])
        XCTAssertTrue(output.contains("n1"))
        XCTAssertTrue(output.contains("n2"))
    }

    // MARK: - Helpers

    private func makeBook(title: String, author: String?) -> Book {
        let book = Book(title: title, author: author)
        book.notes = []
        return book
    }

    private func makeNote(
        book: Book,
        chapter: String?,
        highlight: String,
        userNote: String? = nil,
        location: String? = nil,
        sourceURL: String? = nil,
        isFavorite: Bool = false,
        reviewCount: Int = 0
    ) -> ReadingNote {
        let note = ReadingNote(
            book: book,
            chapter: chapter,
            highlight: highlight,
            userNote: userNote,
            location: location,
            isFavorite: isFavorite,
            reviewCount: reviewCount,
            source: "test",
            sourceURL: sourceURL,
            sourceHash: "test-\(UUID().uuidString)"
        )
        return note
    }
}
