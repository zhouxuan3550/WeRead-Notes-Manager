import XCTest
@testable import WeReadNotesManager

final class ImportPipelineTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportPipelineTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testParseMarkdown_BasicStructure() throws {
        let markdown = """
        # 《长安的荔枝》

        作者：马伯庸

        ## 第一章

        > 一骑红尘妃子笑，无人知是荔枝来。

        我的想法：很好的开篇
        """
        let url = tempDir.appendingPathComponent("test.md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)

        let result = try ImportPipeline.parse(url: url)

        XCTAssertEqual(result.books.count, 1)
        XCTAssertEqual(result.books.first?.title, "长安的荔枝")
        XCTAssertEqual(result.books.first?.author, "马伯庸")
        XCTAssertEqual(result.notes.count, 1)
        XCTAssertEqual(result.notes.first?.highlight, "一骑红尘妃子笑，无人知是荔枝来。")
        XCTAssertEqual(result.notes.first?.userNote, "很好的开篇")
        XCTAssertEqual(result.notes.first?.chapter, "第一章")
    }

    func testParseTXT_BookAndHighlight() throws {
        let txt = """
        书名：长安的荔枝
        作者：马伯庸
        章节：第一章
        划线：一骑红尘妃子笑
        想法：有意思
        """
        let url = tempDir.appendingPathComponent("test.txt")
        try txt.write(to: url, atomically: true, encoding: .utf8)

        let result = try ImportPipeline.parse(url: url)
        XCTAssertEqual(result.notes.count, 1)
        XCTAssertEqual(result.books.first?.title, "长安的荔枝")
        XCTAssertEqual(result.notes.first?.highlight, "一骑红尘妃子笑")
        XCTAssertEqual(result.notes.first?.userNote, "有意思")
    }

    func testParseWeReadSkillText_ChapterAndHighlight() throws {
        let text = """
        书名：长安的荔枝
        作者：马伯庸

        ◆ 第一章

        >> 一骑红尘妃子笑，无人知是荔枝来。

        -- 这是一段想法
        """
        let url = tempDir.appendingPathComponent("weread.txt")
        try text.write(to: url, atomically: true, encoding: .utf8)

        let result = try ImportPipeline.parse(url: url)
        XCTAssertEqual(result.notes.count, 1)
        XCTAssertEqual(result.books.first?.title, "长安的荔枝")
        XCTAssertEqual(result.notes.first?.chapter, "第一章")
        XCTAssertEqual(result.notes.first?.highlight, "一骑红尘妃子笑，无人知是荔枝来。")
        XCTAssertEqual(result.notes.first?.userNote, "这是一段想法")
    }

    func testParse_UnsupportedExtension_Throws() throws {
        let url = tempDir.appendingPathComponent("test.xyz")
        try "data".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ImportPipeline.parse(url: url))
    }

    func testParse_NoBook_ProducesFailure() throws {
        let markdown = """
        ## 没有一级标题

        > 一些划线
        """
        let url = tempDir.appendingPathComponent("nobook.md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)

        let result = try ImportPipeline.parse(url: url)
        XCTAssertFalse(result.failures.isEmpty, "未找到书名时应至少有一条 failure")
    }
}
