import Foundation
import SwiftData

struct CloudSyncSummary: Sendable {
    let books: Int
    let notesCreated: Int
    let notesUpdated: Int
    let fileURL: URL?

    var message: String {
        if notesCreated == 0 && notesUpdated == 0 {
            return "iCloud 已是最新，没有新增笔记。"
        }
        return "iCloud 同步完成，新增 \(notesCreated) 条，更新 \(notesUpdated) 条。"
    }
}

enum ICloudSyncService {
    private static let folderName = "书摘温故"
    private static let snapshotFileName = "library-snapshot.json"

    static func cloudDirectory() throws -> URL {
        let fm = FileManager.default
        let base = fm.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)

        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func snapshotURL() throws -> URL {
        try cloudDirectory().appendingPathComponent(snapshotFileName)
    }

    static func latestSnapshotDate() -> Date? {
        guard let url = try? snapshotURL() else { return nil }
        return try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    static func upload(books: [Book]) throws -> CloudSyncSummary {
        let snapshot = LibraryCloudSnapshot(books: books)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let url = try snapshotURL()
        try data.write(to: url, options: [.atomic])
        UserDefaults.standard.set(Date(), forKey: "iCloudLastUploadAt")
        return CloudSyncSummary(
            books: snapshot.books.count,
            notesCreated: snapshot.books.reduce(0) { $0 + $1.notes.count },
            notesUpdated: 0,
            fileURL: url
        )
    }

    static func download(container: ModelContainer) async throws -> CloudSyncSummary {
        let url = try snapshotURL()
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(LibraryCloudSnapshot.self, from: data)
        let actor = CloudSnapshotImportActor(modelContainer: container)
        let summary = try await actor.merge(snapshot)
        UserDefaults.standard.set(Date(), forKey: "iCloudLastDownloadAt")
        return CloudSyncSummary(
            books: summary.books,
            notesCreated: summary.notesCreated,
            notesUpdated: summary.notesUpdated,
            fileURL: url
        )
    }
}

struct LibraryCloudSnapshot: Codable {
    let version: Int
    let exportedAt: Date
    let books: [CloudBook]

    init(version: Int = 1, exportedAt: Date = Date(), books: [CloudBook]) {
        self.version = version
        self.exportedAt = exportedAt
        self.books = books
    }

    init(books: [Book]) {
        self.version = 1
        self.exportedAt = Date()
        self.books = books
            .filter { !$0.notes.isEmpty }
            .map(CloudBook.init(book:))
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}

struct CloudBook: Codable {
    let id: UUID
    let title: String
    let author: String?
    let coverPath: String?
    let coverURL: String?
    let createdAt: Date
    let updatedAt: Date
    let lastImportedAt: Date?
    let notes: [CloudNote]

    init(book: Book) {
        id = book.id
        title = book.title
        author = book.author
        coverPath = book.coverPath
        coverURL = book.coverURL
        createdAt = book.createdAt
        updatedAt = book.updatedAt
        lastImportedAt = book.lastImportedAt
        notes = book.notes
            .filter { !$0.isDeleted }
            .map(CloudNote.init(note:))
            .sorted { ($0.createdAt ?? $0.importedAt) < ($1.createdAt ?? $1.importedAt) }
    }
}

struct CloudNote: Codable {
    let id: UUID
    let chapter: String?
    let highlight: String
    let userNote: String?
    let location: String?
    let createdAt: Date?
    let importedAt: Date
    let updatedAt: Date
    let isFavorite: Bool
    let isReviewed: Bool
    let reviewCount: Int
    let lastReviewedAt: Date?
    let source: String
    let sourceID: String?
    let sourceURL: String?
    let noteKind: String?
    let sourceHash: String
    let easeFactor: Double
    let intervalDays: Int
    let repetitions: Int
    let nextReviewAt: Date?

    init(note: ReadingNote) {
        id = note.id
        chapter = note.chapter
        highlight = note.highlight
        userNote = note.userNote
        location = note.location
        createdAt = note.createdAt
        importedAt = note.importedAt
        updatedAt = note.updatedAt
        isFavorite = note.isFavorite
        isReviewed = note.isReviewed
        reviewCount = note.reviewCount
        lastReviewedAt = note.lastReviewedAt
        source = note.source
        sourceID = note.sourceID
        sourceURL = note.sourceURL
        noteKind = note.noteKind
        sourceHash = note.sourceHash
        easeFactor = note.easeFactor
        intervalDays = note.intervalDays
        repetitions = note.repetitions
        nextReviewAt = note.nextReviewAt
    }
}

@ModelActor
actor CloudSnapshotImportActor {
    struct MergeResult: Sendable {
        let books: Int
        let notesCreated: Int
        let notesUpdated: Int
    }

    func merge(_ snapshot: LibraryCloudSnapshot) throws -> MergeResult {
        var bookCache = buildBookCache()
        var noteCache = buildNoteCache()
        var notesCreated = 0
        var notesUpdated = 0

        for cloudBook in snapshot.books {
            let book = findOrCreateBook(cloudBook, cache: &bookCache)

            for cloudNote in cloudBook.notes {
                if let existing = noteCache[cloudNote.sourceHash] {
                    if cloudNote.updatedAt > existing.updatedAt {
                        apply(cloudNote, to: existing, book: book)
                        notesUpdated += 1
                    }
                } else {
                    let note = ReadingNote(
                        id: cloudNote.id,
                        book: book,
                        chapter: cloudNote.chapter,
                        highlight: cloudNote.highlight,
                        userNote: cloudNote.userNote,
                        location: cloudNote.location,
                        createdAt: cloudNote.createdAt,
                        importedAt: cloudNote.importedAt,
                        updatedAt: cloudNote.updatedAt,
                        isFavorite: cloudNote.isFavorite,
                        isReviewed: cloudNote.isReviewed,
                        reviewCount: cloudNote.reviewCount,
                        lastReviewedAt: cloudNote.lastReviewedAt,
                        source: cloudNote.source,
                        sourceID: cloudNote.sourceID,
                        sourceURL: cloudNote.sourceURL,
                        noteKind: cloudNote.noteKind ?? "highlight",
                        sourceHash: cloudNote.sourceHash
                    )
                    note.easeFactor = cloudNote.easeFactor
                    note.intervalDays = cloudNote.intervalDays
                    note.repetitions = cloudNote.repetitions
                    note.nextReviewAt = cloudNote.nextReviewAt
                    book.notes.append(note)
                    noteCache[cloudNote.sourceHash] = note
                    notesCreated += 1
                }
            }
            book.updatedAt = max(book.updatedAt, cloudBook.updatedAt)
            book.lastImportedAt = cloudBook.lastImportedAt ?? book.lastImportedAt
        }

        try modelContext.save()
        return MergeResult(books: snapshot.books.count, notesCreated: notesCreated, notesUpdated: notesUpdated)
    }

    private func buildBookCache() -> [String: Book] {
        let books = (try? modelContext.fetch(FetchDescriptor<Book>())) ?? []
        var cache: [String: Book] = [:]
        for book in books {
            cache[bookKey(title: book.title, author: book.author)] = book
        }
        return cache
    }

    private func buildNoteCache() -> [String: ReadingNote] {
        let notes = (try? modelContext.fetch(FetchDescriptor<ReadingNote>())) ?? []
        var cache: [String: ReadingNote] = [:]
        for note in notes where !note.sourceHash.isEmpty {
            cache[note.sourceHash] = note
        }
        return cache
    }

    private func findOrCreateBook(_ cloudBook: CloudBook, cache: inout [String: Book]) -> Book {
        let key = bookKey(title: cloudBook.title, author: cloudBook.author)
        if let existing = cache[key] {
            existing.author = existing.author ?? cloudBook.author
            existing.coverURL = existing.coverURL ?? cloudBook.coverURL
            existing.coverPath = existing.coverPath ?? cloudBook.coverPath
            return existing
        }

        let book = Book(
            id: cloudBook.id,
            title: cloudBook.title,
            author: cloudBook.author,
            coverPath: cloudBook.coverPath,
            coverURL: cloudBook.coverURL,
            createdAt: cloudBook.createdAt,
            updatedAt: cloudBook.updatedAt,
            lastImportedAt: cloudBook.lastImportedAt
        )
        modelContext.insert(book)
        cache[key] = book
        return book
    }

    private func apply(_ cloudNote: CloudNote, to note: ReadingNote, book: Book) {
        note.book = book
        note.chapter = cloudNote.chapter
        note.highlight = cloudNote.highlight
        note.userNote = cloudNote.userNote
        note.location = cloudNote.location
        note.createdAt = cloudNote.createdAt
        note.importedAt = cloudNote.importedAt
        note.updatedAt = cloudNote.updatedAt
        note.isFavorite = cloudNote.isFavorite
        note.isReviewed = cloudNote.isReviewed
        note.reviewCount = cloudNote.reviewCount
        note.lastReviewedAt = cloudNote.lastReviewedAt
        note.sourceURL = cloudNote.sourceURL
        note.noteKind = cloudNote.noteKind
        note.easeFactor = cloudNote.easeFactor
        note.intervalDays = cloudNote.intervalDays
        note.repetitions = cloudNote.repetitions
        note.nextReviewAt = cloudNote.nextReviewAt
    }

    private func bookKey(title: String, author: String?) -> String {
        "\(title.normalizedForHash())|\((author ?? "").normalizedForHash())"
    }
}
