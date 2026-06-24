import Foundation
import SwiftData

struct ImportService {
    let modelContext: ModelContext
    let skipDuplicates: Bool

    init(modelContext: ModelContext, skipDuplicates: Bool = true) {
        self.modelContext = modelContext
        self.skipDuplicates = skipDuplicates
    }

    func importFile(_ url: URL) throws -> (record: ImportRecord, detail: String) {
        let importer = try selectImporter(for: url)
        let ext = url.pathExtension.lowercased()

        let result = try importer.importNotes(from: url)
        return try importResult(
            result,
            fileName: url.lastPathComponent,
            fileType: ext,
            sourceName: importer.sourceName
        )
    }

    func importResult(
        _ result: ImportResult,
        fileName: String,
        fileType: String,
        sourceName: String
    ) throws -> (record: ImportRecord, detail: String) {
        var booksCreated = 0
        var notesCreated = 0
        var duplicatesSkipped = 0
        let failedCount = result.failures.count

        // 一次性拉取已有 sourceHash + 书籍缓存，避免对每条笔记反复查询。
        var existingHashes = getExistingHashes()
        var bookCache = buildBookCache()

        // 先把 result.books 里独立的书插入并入缓存
        for importedBook in result.books {
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

        SafePersistence.save(modelContext, label: "importResult:notes")

        let record = ImportRecord(
            fileName: fileName,
            fileType: fileType,
            source: sourceName,
            booksCreated: booksCreated,
            notesCreated: notesCreated,
            duplicatesSkipped: duplicatesSkipped,
            failedCount: failedCount,
            message: makeDetail(notesCreated: notesCreated, duplicatesSkipped: duplicatesSkipped, failures: result.failures)
        )
        modelContext.insert(record)
        SafePersistence.save(modelContext, label: "importResult:record")

        let detail = makeDetail(notesCreated: notesCreated, duplicatesSkipped: duplicatesSkipped, failures: result.failures)
        return (record, detail)
    }

    private func selectImporter(for url: URL) throws -> NoteImporter {
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

    /// 读取已存在的 sourceHash 集合。`SortDescriptor` 让数据库走索引（如未来加了）。
    private func getExistingHashes() -> Set<String> {
        var descriptor = FetchDescriptor<ReadingNote>()
        descriptor.sortBy = [SortDescriptor(\.sourceHash)]
        let notes = SafePersistence.fetch(modelContext, descriptor, label: "getExistingHashes")
        return Set(notes.map { $0.sourceHash })
    }

    /// 把现有 Book 按 `(title|author)` 缓存，导入期间复用。
    private func buildBookCache() -> [String: Book] {
        let descriptor = FetchDescriptor<Book>()
        let books = SafePersistence.fetch(modelContext, descriptor, label: "buildBookCache")
        var cache: [String: Book] = [:]
        cache.reserveCapacity(books.count)
        for book in books {
            cache[bookKey(title: book.title, author: book.author)] = book
        }
        return cache
    }

    private func makeDetail(notesCreated: Int, duplicatesSkipped: Int, failures: [ImportFailure]) -> String {
        var detail = "成功导入 \(notesCreated) 条笔记"
        if duplicatesSkipped > 0 {
            detail += "，跳过 \(duplicatesSkipped) 条重复"
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
}

enum ImportError: Error, LocalizedError {
    case unsupportedFormat(String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "不支持的文件格式: .\(ext)。目前支持 Markdown (.md)、纯文本 (.txt) 和微信读书 Skill JSON (.json)。"
        case .parseFailed(let msg):
            return "解析失败：\(msg)"
        }
    }
}
