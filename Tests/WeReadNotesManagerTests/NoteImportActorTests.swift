import XCTest
import SwiftData
@testable import WeReadNotesManager

@MainActor
final class NoteImportActorTests: XCTestCase {
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

    func testPersist_CreatesBooksAndNotes() async throws {
        let result = makeResult(books: [
            ImportedBook(title: "测试书", author: "作者", coverURL: nil)
        ], notes: [
            ImportedNote(
                bookTitle: "测试书",
                author: "作者",
                chapter: "第一章",
                highlight: "划线1",
                userNote: nil,
                location: nil,
                createdAt: nil,
                source: "manual",
                sourceID: nil
            )
        ])

        let actor = NoteImportActor(modelContainer: container)
        let record = try await actor.persist(
            result,
            fileName: "test.md",
            fileType: "md",
            sourceName: "markdown"
        )

        XCTAssertEqual(record.booksCreated, 1)
        XCTAssertEqual(record.notesCreated, 1)
        XCTAssertEqual(record.duplicatesSkipped, 0)

        let books = try container.mainContext.fetch(FetchDescriptor<Book>())
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?.title, "测试书")
        XCTAssertEqual(books.first?.notes.count, 1)
        XCTAssertEqual(books.first?.notes.first?.highlight, "划线1")
    }

    func testPersist_SkipsDuplicatesByHash() async throws {
        // 预先通过同一 actor 插入一条笔记
        let actor = NoteImportActor(modelContainer: container)
        let setup = makeResult(
            books: [ImportedBook(title: "测试书", author: "作者", coverURL: nil)],
            notes: [
                ImportedNote(
                    bookTitle: "测试书",
                    author: "作者",
                    chapter: "第一章",
                    highlight: "划线1",
                    userNote: nil,
                    location: nil,
                    createdAt: nil,
                    source: "manual",
                    sourceID: nil
                )
            ]
        )
        _ = try await actor.persist(setup, fileName: "setup", fileType: "md", sourceName: "markdown")

        // 再导入相同内容应该被跳过
        let record = try await actor.persist(
            setup,
            fileName: "test.md",
            fileType: "md",
            sourceName: "markdown"
        )

        XCTAssertEqual(record.notesCreated, 0)
        XCTAssertEqual(record.duplicatesSkipped, 1)

        let books = try container.mainContext.fetch(FetchDescriptor<Book>())
        XCTAssertEqual(books.first?.notes.count, 1, "重复笔记不应被插入")
    }

    func testPersist_ReusesExistingBook() async throws {
        // 预插入一本书（通过 actor 写入，actor 的 context 看得到）
        let actor = NoteImportActor(modelContainer: container)
        let setup = makeResult(
            books: [ImportedBook(title: "测试书", author: "已知作者", coverURL: nil)],
            notes: []
        )
        _ = try await actor.persist(setup, fileName: "setup", fileType: "md", sourceName: "markdown")

        // 再导入一条笔记到同一本书，作者匹配 → 复用，不新建
        let result = makeResult(books: [], notes: [
            ImportedNote(
                bookTitle: "测试书",
                author: "已知作者",
                chapter: nil,
                highlight: "n",
                userNote: nil,
                location: nil,
                createdAt: nil,
                source: "manual",
                sourceID: nil
            )
        ])

        let record = try await actor.persist(
            result,
            fileName: "test.md",
            fileType: "md",
            sourceName: "markdown"
        )

        XCTAssertEqual(record.booksCreated, 0, "已存在书不应被计为新建")
        XCTAssertEqual(record.notesCreated, 1)

        let books = try container.mainContext.fetch(FetchDescriptor<Book>())
        XCTAssertEqual(books.count, 1, "不应新建重复书")
    }

    func testPersist_DifferentAuthor_CreatesNewBook() async throws {
        // 验证：用不同 author 的笔记会创建独立书条目（保留 provenance）。
        let actor = NoteImportActor(modelContainer: container)
        _ = try await actor.persist(
            makeResult(
                books: [ImportedBook(title: "测试书", author: "作者A", coverURL: nil)],
                notes: []
            ),
            fileName: "setup",
            fileType: "md",
            sourceName: "markdown"
        )

        _ = try await actor.persist(
            makeResult(books: [], notes: [
                ImportedNote(
                    bookTitle: "测试书",
                    author: "作者B",
                    chapter: nil,
                    highlight: "n",
                    userNote: nil,
                    location: nil,
                    createdAt: nil,
                    source: "manual",
                    sourceID: nil
                )
            ]),
            fileName: "test",
            fileType: "md",
            sourceName: "markdown"
        )

        let books = try container.mainContext.fetch(FetchDescriptor<Book>())
        XCTAssertEqual(books.count, 2, "不同 author 应保留为独立书条目")
    }

    // MARK: - Helpers

    private func makeResult(books: [ImportedBook], notes: [ImportedNote]) -> ImportResult {
        ImportResult(books: books, notes: notes, failures: [])
    }
}
