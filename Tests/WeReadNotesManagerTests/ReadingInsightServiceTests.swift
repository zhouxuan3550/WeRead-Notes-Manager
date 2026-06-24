import XCTest
import SwiftData
@testable import WeReadNotesManager

@MainActor
final class ReadingInsightServiceTests: XCTestCase {
    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([Book.self, ReadingNote.self, ImportRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    func testKeywords_FiltersStopWords() {
        let tokens = ReadingInsightService.keywords(in: "一个 故事 我们 编程 机器")
        XCTAssertFalse(tokens.contains("一个"))
        XCTAssertFalse(tokens.contains("我们"))
        XCTAssertTrue(tokens.contains("故事"))
        XCTAssertTrue(tokens.contains("编程"))
        XCTAssertTrue(tokens.contains("机器"))
    }

    func testKeywords_Deduplicates() {
        let tokens = ReadingInsightService.keywords(in: "故事 故事 故事")
        XCTAssertEqual(tokens.filter { $0 == "故事" }.count, 1)
    }

    func testKeywords_HandlesMixedChineseAndEnglish() {
        let tokens = ReadingInsightService.keywords(in: "Hello 算法 world 你好 Swift")
        XCTAssertTrue(tokens.contains("hello"))
        XCTAssertTrue(tokens.contains("算法"))
        XCTAssertTrue(tokens.contains("world"))
        XCTAssertTrue(tokens.contains("你好"))
        XCTAssertTrue(tokens.contains("swift"))
    }

    func testThemeClusters_FiltersClustersBelowThreshold() {
        let note1 = makeNote(book: nil, highlight: "算法很重要")
        let note2 = makeNote(book: nil, highlight: "算法改变世界")
        let clusters = ReadingInsightService.themeClusters(fromNotes: [note1, note2])
        // "算法" 在两条笔记都出现，应该作为 cluster 出现
        XCTAssertTrue(clusters.contains { $0.title == "算法" })
        // 只有一条笔记的 cluster 应该被过滤掉
        XCTAssertFalse(clusters.contains { $0.count < 2 })
    }

    // MARK: - Helpers

    private func makeNote(book: Book?, highlight: String, chapter: String? = nil, userNote: String? = nil) -> ReadingNote {
        ReadingNote(
            book: book,
            chapter: chapter,
            highlight: highlight,
            userNote: userNote,
            sourceHash: "test-\(UUID().uuidString)"
        )
    }
}
