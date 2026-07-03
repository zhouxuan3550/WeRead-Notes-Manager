import Foundation
import SwiftData

// MARK: - 纯函数解析层（同步）

/// 解析层的纯函数接口。可以独立于 SwiftData 单测。
enum ImportPipeline {
    /// 根据 URL 后缀选择 Importer 并解析。
    static func parse(url: URL) throws -> ImportResult {
        let importer = try selectImporter(for: url)
        return try importer.importNotes(from: url)
    }

    static func parse(_ data: Data, fileType: String, fileName: String) throws -> ImportResult {
        // 同步辅助：用于 API 调用结果直接传入。
        // 注意：API 调用结果是 ImportResult，本函数主要提供给 importer 的扩展点。
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try parse(url: tempURL)
    }

    static func selectImporter(for url: URL) throws -> NoteImporter {
        let ext = url.pathExtension.lowercased()
        let candidates: [NoteImporter]
        switch ext {
        case "json":
            candidates = [WeReadSkillImporter()]
        case "md", "markdown":
            candidates = [MarkdownNoteImporter()]
        case "txt":
            candidates = [WeReadSkillImporter(), TXTNoteImporter()]
        default:
            throw ImportError.unsupportedFormat(ext)
        }
        if let importer = candidates.first(where: { $0.canImport(fileURL: url) }) {
            return importer
        }
        throw ImportError.unsupportedFormat(ext)
    }
}

// MARK: - 后台落库 Actor

/// 后台落库 Actor，把所有 `modelContext.save()` 放到独立线程。
///
/// 之前 `ImportService.importResult` 在 `MainActor.run` 中跑，会阻塞 UI。
/// 用 `@ModelActor` 创建独立的 ModelContext（与 View 持有的 context 隔离），
/// 因此在 actor 内的所有 `context.insert / context.save` 都不再争抢主线程。
@ModelActor
actor NoteImportActor {
    /// 把解析结果落库，返回普通值快照。
    ///
    /// - Parameters:
    ///   - skipDuplicates: 是否按 `sourceHash` 跳过重复
    ///   - onProgress: 进度回调（actor 内部，可以从 sync 方法转译）
    func persist(
        _ result: ImportResult,
        fileName: String,
        fileType: String,
        sourceName: String,
        skipDuplicates: Bool = true,
        minNotesPerBook: Int = 0
    ) throws -> PersistedImportSummary {
        var booksCreated = 0
        var notesCreated = 0
        var duplicatesSkipped = 0
        let failedCount = result.failures.count
        let bookNoteCounts = Self.bookNoteCounts(for: result.notes)
        let allowedBookKeys = Set(bookNoteCounts.compactMap { key, count in
            minNotesPerBook > 0 && count < minNotesPerBook ? nil : key
        })
        let skippedBookCount = minNotesPerBook > 0
            ? bookNoteCounts.values.filter { $0 < minNotesPerBook }.count
            : 0
        let lowCountNotesSkipped = minNotesPerBook > 0
            ? result.notes.filter { !allowedBookKeys.contains(bookKey(title: $0.bookTitle, author: $0.author)) }.count
            : 0
        let skippedLowNoteBooks = minNotesPerBook > 0
            ? Self.skippedLowNoteBooks(from: result.notes, counts: bookNoteCounts, minNotesPerBook: minNotesPerBook)
            : []

        var existingHashes = getExistingHashes()
        var bookCache = buildBookCache()

        // 先把 result.books 里独立的书插入并入缓存
        for importedBook in result.books {
            if minNotesPerBook > 0,
               !allowedBookKeys.contains(bookKey(title: importedBook.title, author: importedBook.author)) {
                continue
            }
            let (_, created) = findOrCreateBook(
                title: importedBook.title,
                author: importedBook.author,
                coverURL: importedBook.coverURL,
                cache: &bookCache
            )
            if created {
                booksCreated += 1
            }
        }

        for importedNote in result.notes {
            if minNotesPerBook > 0,
               !allowedBookKeys.contains(bookKey(title: importedNote.bookTitle, author: importedNote.author)) {
                continue
            }

            let hash = HashService.generateHash(
                source: importedNote.source,
                sourceID: importedNote.sourceID,
                bookTitle: importedNote.bookTitle,
                author: importedNote.author,
                chapter: importedNote.chapter,
                highlight: importedNote.highlight,
                userNote: importedNote.userNote,
                location: importedNote.location
            )

            if skipDuplicates && existingHashes.contains(hash) {
                duplicatesSkipped += 1
                continue
            }
            existingHashes.insert(hash)

            let (book, created) = findOrCreateBook(
                title: importedNote.bookTitle,
                author: importedNote.author,
                cache: &bookCache
            )
            if created {
                booksCreated += 1
            }
            let note = ReadingNote(
                book: book,
                chapter: importedNote.chapter,
                highlight: importedNote.highlight,
                userNote: importedNote.userNote,
                location: importedNote.location,
                createdAt: importedNote.createdAt,
                source: importedNote.source,
                sourceID: importedNote.sourceID,
                sourceURL: importedNote.sourceURL,
                noteKind: importedNote.noteKind,
                sourceHash: hash
            )
            book.notes.append(note)
            book.lastImportedAt = Date()
            book.updatedAt = Date()
            notesCreated += 1
        }

        try modelContext.save()

        let record = ImportRecord(
            fileName: fileName,
            fileType: fileType,
            source: sourceName,
            booksCreated: booksCreated,
            notesCreated: notesCreated,
            duplicatesSkipped: duplicatesSkipped,
            failedCount: failedCount,
            message: Self.makeDetail(
                notesCreated: notesCreated,
                duplicatesSkipped: duplicatesSkipped,
                lowCountNotesSkipped: lowCountNotesSkipped,
                skippedBookCount: skippedBookCount,
                minNotesPerBook: minNotesPerBook,
                failures: result.failures
            )
        )
        modelContext.insert(record)
        try modelContext.save()

        return PersistedImportSummary(record)
            .withSkippedLowNoteBooks(skippedLowNoteBooks)
    }

    private func getExistingHashes() -> Set<String> {
        var descriptor = FetchDescriptor<ReadingNote>()
        descriptor.sortBy = [SortDescriptor(\.sourceHash)]
        let notes = (try? modelContext.fetch(descriptor)) ?? []
        return Set(notes.map { $0.sourceHash })
    }

    private func buildBookCache() -> [String: Book] {
        let descriptor = FetchDescriptor<Book>()
        let books = (try? modelContext.fetch(descriptor)) ?? []
        var cache: [String: Book] = [:]
        cache.reserveCapacity(books.count)
        for book in books {
            cache[bookKey(title: book.title, author: book.author)] = book
        }
        return cache
    }

    private func findOrCreateBook(
        title: String,
        author: String?,
        coverURL: String? = nil,
        cache: inout [String: Book]
    ) -> (Book, Bool) {
        let key = bookKey(title: title, author: author)
        if let existing = cache[key] {
            var changed = false
            if existing.author == nil, let author {
                existing.author = author
                changed = true
            }
            if existing.coverURL == nil, let coverURL {
                existing.coverURL = coverURL
                changed = true
            }
            if changed { existing.updatedAt = Date() }
            return (existing, false)
        }
        let book = Book(title: title, author: author, coverURL: coverURL)
        modelContext.insert(book)
        cache[key] = book
        return (book, true)
    }

    private func bookKey(title: String, author: String?) -> String {
        "\(title.normalizedForHash())|\((author ?? "").normalizedForHash())"
    }

    private static func bookNoteCounts(for notes: [ImportedNote]) -> [String: Int] {
        Dictionary(grouping: notes) { note in
            "\(note.bookTitle.normalizedForHash())|\((note.author ?? "").normalizedForHash())"
        }
        .mapValues(\.count)
    }

    private static func skippedLowNoteBooks(
        from notes: [ImportedNote],
        counts: [String: Int],
        minNotesPerBook: Int
    ) -> [SkippedImportBook] {
        var seen: Set<String> = []
        return notes.compactMap { note in
            let key = "\(note.bookTitle.normalizedForHash())|\((note.author ?? "").normalizedForHash())"
            guard let count = counts[key], count < minNotesPerBook, !seen.contains(key) else {
                return nil
            }
            seen.insert(key)
            return SkippedImportBook(title: note.bookTitle, author: note.author, noteCount: count)
        }
        .sorted { lhs, rhs in
            if lhs.noteCount != rhs.noteCount { return lhs.noteCount < rhs.noteCount }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private static func makeDetail(
        notesCreated: Int,
        duplicatesSkipped: Int,
        lowCountNotesSkipped: Int,
        skippedBookCount: Int,
        minNotesPerBook: Int,
        failures: [ImportFailure]
    ) -> String {
        var detail = "成功导入 \(notesCreated) 条笔记"
        if duplicatesSkipped > 0 {
            detail += "，跳过 \(duplicatesSkipped) 条重复"
        }
        if minNotesPerBook > 0, lowCountNotesSkipped > 0 {
            detail += "，屏蔽 \(skippedBookCount) 本少于 \(minNotesPerBook) 条笔记的书（\(lowCountNotesSkipped) 条笔记）"
        }
        if !failures.isEmpty {
            detail += "，\(failures.count) 条解析失败"
            let reasons = failures.prefix(2).map { failure in
                if let lineNumber = failure.lineNumber {
                    return "第 \(lineNumber) 行：\(failure.reason)"
                }
                return failure.reason
            }
            detail += "。\(reasons.joined(separator: "；"))"
        }
        return detail
    }
}

/// 导入完成后给 UI 使用的普通值对象。
///
/// SwiftData 的 `@Model` 对象绑定在创建它的 ModelContext/Actor 上，不能把
/// `ImportRecord` 直接从后台 actor 交给主线程读取。否则大量导入收尾时，
/// UI 访问 `record.fileName` 这类属性会触发 SwiftData 断言崩溃。
struct PersistedImportSummary: Sendable {
    let fileName: String
    let fileType: String
    let source: String
    let booksCreated: Int
    let notesCreated: Int
    let duplicatesSkipped: Int
    let failedCount: Int
    let message: String
    let skippedLowNoteBooks: [SkippedImportBook]

    init(
        fileName: String,
        fileType: String,
        source: String,
        booksCreated: Int,
        notesCreated: Int,
        duplicatesSkipped: Int,
        failedCount: Int,
        message: String,
        skippedLowNoteBooks: [SkippedImportBook] = []
    ) {
        self.fileName = fileName
        self.fileType = fileType
        self.source = source
        self.booksCreated = booksCreated
        self.notesCreated = notesCreated
        self.duplicatesSkipped = duplicatesSkipped
        self.failedCount = failedCount
        self.message = message
        self.skippedLowNoteBooks = skippedLowNoteBooks
    }

    init(_ record: ImportRecord) {
        self.init(
            fileName: record.fileName,
            fileType: record.fileType,
            source: record.source,
            booksCreated: record.booksCreated,
            notesCreated: record.notesCreated,
            duplicatesSkipped: record.duplicatesSkipped,
            failedCount: record.failedCount,
            message: record.message ?? "导入完成",
            skippedLowNoteBooks: []
        )
    }

    func withSkippedLowNoteBooks(_ books: [SkippedImportBook]) -> PersistedImportSummary {
        PersistedImportSummary(
            fileName: fileName,
            fileType: fileType,
            source: source,
            booksCreated: booksCreated,
            notesCreated: notesCreated,
            duplicatesSkipped: duplicatesSkipped,
            failedCount: failedCount,
            message: message,
            skippedLowNoteBooks: books
        )
    }
}

struct SkippedImportBook: Sendable, Equatable {
    let title: String
    let author: String?
    let noteCount: Int

    var displayName: String {
        if let author, !author.isEmpty {
            return "《\(title)》\(author) · \(noteCount) 条"
        }
        return "《\(title)》· \(noteCount) 条"
    }
}

// MARK: - 门面：MainActor 异步入口

/// View 层使用的统一异步门面。
///
/// 用法：
/// ```swift
/// let record = try await ImportCoordinator(container: modelContainer)
///     .importFile(url)
/// ```
@MainActor
struct ImportCoordinator {
    let container: ModelContainer
    let skipDuplicates: Bool
    let minNotesPerBook: Int

    init(container: ModelContainer, skipDuplicates: Bool = true, minNotesPerBook: Int = 0) {
        self.container = container
        self.skipDuplicates = skipDuplicates
        self.minNotesPerBook = minNotesPerBook
    }

    func importFile(_ url: URL) async throws -> PersistedImportSummary {
        // 解析在调用线程（通常是 main）跑，但只做纯文本解析，CPU 占用小
        let result = try ImportPipeline.parse(url: url)
        let ext = url.pathExtension.lowercased()
        let sourceName = try ImportPipeline.selectImporter(for: url).sourceName

        // 落库搬到 NoteImportActor
        let actor = NoteImportActor(modelContainer: container)
        return try await actor.persist(
            result,
            fileName: url.lastPathComponent,
            fileType: ext,
            sourceName: sourceName,
            skipDuplicates: skipDuplicates,
            minNotesPerBook: minNotesPerBook
        )
    }

    /// 微信读书 API 同步入口：解析 + 落库，进度通过 AsyncStream 返回。
    func syncWeRead(
        apiKey: String,
        onProgress: @MainActor @escaping (WeReadSyncProgress) -> Void = { _ in }
    ) async throws -> PersistedImportSummary {
        let apiService = WeReadAPIService(apiKey: apiKey)
        let stream = apiService.fetchImportResultStream()
        var lastResult: ImportResult?

        for try await update in stream {
            switch update {
            case .progress(let progress):
                onProgress(progress)
            case .completed(let result):
                lastResult = result
            }
        }

        guard let result = lastResult else {
            throw WeReadAPIError.invalidResponse
        }

        let actor = NoteImportActor(modelContainer: container)
        return try await actor.persist(
            result,
            fileName: "微信读书同步",
            fileType: "api",
            sourceName: "weread_skill",
            skipDuplicates: skipDuplicates,
            minNotesPerBook: minNotesPerBook
        )
    }
}

// MARK: - 旧 ImportService 兼容垫片

/// 旧 ImportService 通过 importFile / importResult 提供同步接口。
///
/// 新代码请使用 `ImportCoordinator`。本类仅保留用于过渡期——目前已被
/// MainView / ImportView 调用移除，仅在 SettingsView.exportAllData
/// 这类非热路径上仍可选用。
@available(*, deprecated, message: "Use ImportCoordinator (actor-based)")
typealias LegacyImportService = ImportService
