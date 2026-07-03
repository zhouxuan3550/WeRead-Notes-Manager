import Foundation
import SwiftUI
import SwiftData

@Observable
final class AppViewModel {
    // MARK: - Observable State

    var selectedSidebarItem: SidebarItem? = .dashboard
    var selectedBook: Book?
    var selectedNote: ReadingNote?
    var searchText: String = ""
    var books: [Book] = []
    var noteKindFilter: NoteKindFilter = .all
    var noteSortMode: NoteSortMode = .createdDescending
    var syncState = SyncState()

    // MARK: - 派生缓存（按依赖键自动失效）
    //
    // 用 `SmartCache` 替代手写 invalidation：
    // - 缓存 key = 依赖的所有输入（books 版本号 + 过滤参数）
    // - 输入变化 → key 变化 → 自动失效
    // - 相同 key → 直接返回缓存（O(1)）

    @ObservationIgnored
    private var booksVersion: Int = 0

    @ObservationIgnored
    private let notesCache = SmartCache<Int, [ReadingNote]>()

    @ObservationIgnored
    private let statsCache = SmartCache<Int, LibraryStats>()

    @ObservationIgnored
    private let searchIndexCache = SmartCache<Int, [SearchIndexEntry]>()

    @ObservationIgnored
    private let filteredNotesCache = SmartCache<FilteredKey, [ReadingNote]>()

    @ObservationIgnored
    private let recommendedCache = SmartCache<Int, [ReadingNote]>()

    /// filteredNotes 的复合 key（依赖所有过滤参数）
    struct FilteredKey: Hashable {
        let booksVersion: Int
        let sidebar: SidebarItem?
        let bookID: UUID?
        let search: String
        let kind: NoteKindFilter
        let sort: NoteSortMode
    }

    // MARK: - Books Lifecycle

    func updateBooks(_ newBooks: [Book]) {
        books = newBooks
        booksVersion &+= 1
    }

    func refreshBooks(context: ModelContext) {
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        books = SafePersistence.fetch(context, descriptor, label: "refreshBooks")
        booksVersion &+= 1
    }

    // MARK: - Computed Properties（依赖追踪缓存）

    var allNotes: [ReadingNote] {
        notesCache.get(booksVersion) {
            Perf.measure("allNotes") {
                books.flatMap { $0.notes }.filter { !$0.isDeleted }
            }
        }
    }

    /// 软删除的笔记（用于回收站视图）。
    var trashedNotes: [ReadingNote] {
        books.flatMap { $0.notes }.filter { $0.isDeleted }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    /// 所有用户标签（按笔记数倒序）。
    var allTags: [Tag] {
        let tagSet = Set(allNotes.flatMap { $0.tags })
        return tagSet.sorted { $0.notes.count > $1.notes.count }
    }

    var libraryStats: LibraryStats {
        statsCache.get(booksVersion) {
            computeStats(from: books)
        }
    }

    var filteredNotes: [ReadingNote] {
        let key = FilteredKey(
            booksVersion: booksVersion,
            sidebar: selectedSidebarItem,
            bookID: selectedBook?.id,
            search: searchText,
            kind: noteKindFilter,
            sort: noteSortMode
        )
        return filteredNotesCache.get(key) {
            Perf.measure("filteredNotes") {
                let base: [ReadingNote]
                switch selectedSidebarItem {
                case .allNotes:
                    base = allNotes
                case .favorites:
                    base = allNotes.filter(\.isFavorite)
                case .unreviewed:
                    base = allNotes.filter { !$0.isReviewed }
                case .todayReview:
                    base = reviewRecommendedNotes()
                case .randomNotes:
                    base = Array(allNotes.shuffled().prefix(10))
                case .books:
                    base = selectedBook?.notes ?? allNotes
                case .dashboard, .mindMap, .readingReport, .syncHistory, .settings,
                     .tags, .topicClusters, .knowledgeGraph, .writingCards, .shareCardStudio,
                     .askAI, .writingAssistant, .trash, .none:
                    base = []
                }
                return sortNotes(applyKindFilter(applySearch(base)))
            }
        }
    }

    var filteredBooks: [Book] {
        let defaults = UserDefaults.standard
        let filterLowNoteBooks = defaults.object(forKey: "filterLowNoteBooksOnImport") as? Bool ?? true
        let minNotesPerBook = defaults.object(forKey: "minNotesPerImportedBook") as? Int ?? 5
        return filteredBooks(
            filterLowNoteBooks: filterLowNoteBooks,
            minNotesPerBook: minNotesPerBook
        )
    }

    func filteredBooks(filterLowNoteBooks: Bool, minNotesPerBook: Int) -> [Book] {
        let visibleBooks = applyLowNoteBookFilter(
            books,
            isEnabled: filterLowNoteBooks,
            minNotesPerBook: minNotesPerBook
        )
        return applyBookSearch(visibleBooks)
    }

    // MARK: - Search

    private func applySearch(_ notes: [ReadingNote]) -> [ReadingNote] {
        guard !searchText.isEmpty else { return notes }
        let query = searchText.lowercased()
        return notes.filter { note in
            note.highlight.localizedCaseInsensitiveContains(query)
            || (note.userNote?.localizedCaseInsensitiveContains(query) ?? false)
            || (note.chapter?.localizedCaseInsensitiveContains(query) ?? false)
            || (note.book?.title.localizedCaseInsensitiveContains(query) ?? false)
            || (note.book?.author?.localizedCaseInsensitiveContains(query) ?? false)
            || (note.location?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func searchNotes(
        query: String,
        bookID: UUID?,
        chapter: String,
        onlyThoughts: Bool,
        onlyFavorites: Bool
    ) -> [ReadingNote] {
        let index = searchIndexCache.get(booksVersion) {
            Perf.measure("searchIndex") {
                allNotes.map(SearchIndexEntry.init(note:))
            }
        }
        let normalizedQuery = SearchIndexEntry.normalize(query)
        let candidates = normalizedQuery.isEmpty
            ? index
            : index.filter { $0.haystack.contains(normalizedQuery) }

        return candidates.compactMap { entry in
            let note = entry.note
            if let bookID, note.book?.id != bookID { return nil }
            if chapter != "全部", (note.chapter?.isEmpty == false ? note.chapter! : "未分章") != chapter { return nil }
            if onlyThoughts, note.userNote?.isEmpty != false { return nil }
            if onlyFavorites, !note.isFavorite { return nil }
            return note
        }
        .sorted { ($0.createdAt ?? $0.importedAt) > ($1.createdAt ?? $1.importedAt) }
    }

    private func applyBookSearch(_ books: [Book]) -> [Book] {
        guard !searchText.isEmpty else { return books }
        let query = searchText.lowercased()
        return books.filter {
            $0.title.localizedCaseInsensitiveContains(query)
            || ($0.author?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func applyLowNoteBookFilter(_ books: [Book], isEnabled: Bool, minNotesPerBook: Int) -> [Book] {
        guard isEnabled, minNotesPerBook > 1 else { return books }
        return books.filter { book in
            book.notes.lazy.filter { !$0.isDeleted }.count >= minNotesPerBook
        }
    }

    private func applyKindFilter(_ notes: [ReadingNote]) -> [ReadingNote] {
        switch noteKindFilter {
        case .all:
            return notes
        case .highlights:
            return notes.filter { ($0.noteKind ?? "highlight") == "highlight" || ($0.noteKind ?? "highlight") == "highlight_thought" }
        case .thoughts:
            return notes.filter { $0.userNote?.isEmpty == false || $0.noteKind == "thought" }
        case .reviews:
            return notes.filter { ($0.noteKind ?? "highlight") == "review" }
        }
    }

    private func sortNotes(_ notes: [ReadingNote]) -> [ReadingNote] {
        switch noteSortMode {
        case .createdDescending:
            return notes.sorted { ($0.createdAt ?? $0.importedAt) > ($1.createdAt ?? $1.importedAt) }
        case .importedDescending:
            return notes.sorted { $0.importedAt > $1.importedAt }
        case .chapterAscending:
            return notes.sorted {
                let left = "\($0.book?.title ?? "")|\($0.chapter ?? "")|\($0.location ?? "")"
                let right = "\($1.book?.title ?? "")|\($1.chapter ?? "")|\($1.location ?? "")"
                return left.localizedStandardCompare(right) == .orderedAscending
            }
        case .reviewDue:
            return reviewRecommendedNotes(from: notes)
        }
    }

    // MARK: - Recommended Notes

    func reviewRecommendedNotes() -> [ReadingNote] {
        recommendedCache.get(booksVersion) {
            reviewRecommendedNotes(from: allNotes)
        }
    }

    private func reviewRecommendedNotes(from notes: [ReadingNote]) -> [ReadingNote] {
        notes.map { note -> (ReadingNote, Int) in
            var score = 0
            if !note.isReviewed { score += 50 }
            if note.isFavorite { score += 30 }
            if note.lastReviewedAt == nil { score += 20 }
            let days = note.lastReviewedAt?.daysSince ?? 999
            if days > 90 { score += 40 }
            else if days > 30 { score += 20 }
            return (note, score)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(20)
        .map { $0.0 }
    }

    // MARK: - Mutations

    func markReviewed(_ note: ReadingNote) {
        note.isReviewed = true
        note.reviewCount += 1
        note.lastReviewedAt = Date()
        note.updatedAt = Date()
        // 复习相关字段改变 → 推荐排序需重算
        booksVersion &+= 1
    }

    /// 用 SRS 评级处理一条笔记（Feature 5）。
    func review(_ note: ReadingNote, grade: ReviewGrade, context: ModelContext) {
        let current = SpacedRepetitionService.currentState(of: note)
        let next = SpacedRepetitionService.nextState(after: grade, current: current)
        SpacedRepetitionService.apply(next, to: note, grade: grade)
        SafePersistence.save(context, label: "review:srs")
        booksVersion &+= 1
    }

    /// 当前 due 的笔记（nextReviewAt 为空或 <= 现在）。
    var dueNotes: [ReadingNote] {
        allNotes.filter { SRSState(easeFactor: $0.easeFactor,
                                    intervalDays: $0.intervalDays,
                                    repetitions: $0.repetitions,
                                    nextReviewAt: $0.nextReviewAt).isDue }
    }

    // MARK: - BookSummary (Feature 9)

    func findSummary(for book: Book, context: ModelContext) -> BookSummary? {
        guard let bookID = book.id as UUID? else { return nil }
        var descriptor = FetchDescriptor<BookSummary>(
            predicate: #Predicate { $0.book?.id == bookID }
        )
        descriptor.fetchLimit = 1
        return SafePersistence.fetch(context, descriptor, label: "findSummary").first
    }

    func upsertSummary(for book: Book, content: String, context: ModelContext) {
        if let existing = findSummary(for: book, context: context) {
            existing.content = content
            existing.updatedAt = Date()
        } else {
            let summary = BookSummary(book: book, content: content)
            context.insert(summary)
        }
        SafePersistence.save(context, label: "upsertSummary")
    }

    func toggleFavorite(_ note: ReadingNote) {
        note.isFavorite.toggle()
        note.updatedAt = Date()
        booksVersion &+= 1
    }

    func deleteNote(_ note: ReadingNote, context: ModelContext) {
        // 软删除：设标志位而不是真删，30 天后清理。
        note.isDeleted = true
        note.deletedAt = Date()
        note.updatedAt = Date()
        SafePersistence.save(context, label: "deleteNote:soft")
        invalidateNotesCaches()
        if selectedNote?.id == note.id { selectedNote = nil }
    }

    /// 真正从数据库删除（用于回收站"永久删除"按钮）。
    func purgeNote(_ note: ReadingNote, context: ModelContext) {
        if let book = note.book {
            book.notes.removeAll { $0.id == note.id }
            book.updatedAt = Date()
        }
        context.delete(note)
        SafePersistence.save(context, label: "purgeNote")
        invalidateNotesCaches()
        if selectedNote?.id == note.id { selectedNote = nil }
    }

    /// 恢复软删除的笔记。
    func restoreNote(_ note: ReadingNote, context: ModelContext) {
        note.isDeleted = false
        note.deletedAt = nil
        note.updatedAt = Date()
        SafePersistence.save(context, label: "restoreNote")
        booksVersion &+= 1
    }

    /// 清理超过保留期的已删除笔记。
    func purgeExpiredNotes(retentionDays: Int = 30, context: ModelContext) {
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)
        var descriptor = FetchDescriptor<ReadingNote>(
            predicate: #Predicate { $0.isDeleted && $0.deletedAt != nil }
        )
        descriptor.sortBy = [SortDescriptor(\.deletedAt)]
        let candidates = SafePersistence.fetch(context, descriptor, label: "purgeExpiredNotes")
        let toPurge = candidates.filter { ($0.deletedAt ?? .distantFuture) < cutoff }
        for note in toPurge {
            if let book = note.book {
                book.notes.removeAll { $0.id == note.id }
            }
            context.delete(note)
        }
        if !toPurge.isEmpty {
            SafePersistence.save(context, label: "purgeExpiredNotes:commit")
            booksVersion &+= 1
        }
    }

    func deleteBook(_ book: Book, context: ModelContext) {
        for note in book.notes { context.delete(note) }
        context.delete(book)
        SafePersistence.save(context, label: "deleteBook")
        booksVersion &+= 1
        if selectedBook?.id == book.id {
            selectedBook = nil
            selectedNote = nil
        }
    }

    // MARK: - Batch Operations (Feature 4)

    func batchDeleteNotes(_ notes: [ReadingNote], context: ModelContext) {
        for note in notes {
            note.isDeleted = true
            note.deletedAt = Date()
        }
        SafePersistence.save(context, label: "batchDelete")
        invalidateNotesCaches()
    }

    func batchToggleFavorite(_ notes: [ReadingNote], context: ModelContext, favorite: Bool) {
        for note in notes {
            note.isFavorite = favorite
            note.updatedAt = Date()
        }
        SafePersistence.save(context, label: "batchFavorite")
        invalidateNotesCaches()
    }

    func batchMarkReviewed(_ notes: [ReadingNote], context: ModelContext) {
        for note in notes {
            note.isReviewed = true
            note.reviewCount += 1
            note.lastReviewedAt = Date()
            note.updatedAt = Date()
        }
        SafePersistence.save(context, label: "batchReviewed")
        invalidateAllCaches()
    }

    func batchAddTag(_ tag: Tag, to notes: [ReadingNote], context: ModelContext) {
        for note in notes where !note.tags.contains(where: { $0.id == tag.id }) {
            note.tags.append(tag)
            note.updatedAt = Date()
        }
        SafePersistence.save(context, label: "batchAddTag")
    }

    func batchRemoveTag(_ tag: Tag, from notes: [ReadingNote], context: ModelContext) {
        for note in notes {
            note.tags.removeAll { $0.id == tag.id }
            note.updatedAt = Date()
        }
        SafePersistence.save(context, label: "batchRemoveTag")
    }

    func batchMoveNotes(_ notes: [ReadingNote], to targetBook: Book, context: ModelContext) {
        for note in notes {
            if note.book?.id != targetBook.id {
                note.book?.notes.removeAll { $0.id == note.id }
                note.book = targetBook
                targetBook.notes.append(note)
                targetBook.updatedAt = Date()
            }
        }
        SafePersistence.save(context, label: "batchMove")
        booksVersion &+= 1
    }

    // MARK: - Tag Operations (Feature 3)

    /// 创建或获取已有标签（按 name 归一化匹配）。
    func findOrCreateTag(name: String, colorHex: String? = nil, context: ModelContext) -> Tag? {
        let normalized = Tag.normalize(name: name)
        guard !normalized.isEmpty else { return nil }

        var descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.id == normalized }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let tag = Tag(id: normalized, name: normalized, colorHex: colorHex)
        context.insert(tag)
        return tag
    }

    /// 给笔记打标签（自动去重）。
    func addTag(_ tag: Tag, to note: ReadingNote, context: ModelContext) {
        guard !note.tags.contains(where: { $0.id == tag.id }) else { return }
        note.tags.append(tag)
        note.updatedAt = Date()
        SafePersistence.save(context, label: "addTag")
    }

    func removeTag(_ tag: Tag, from note: ReadingNote, context: ModelContext) {
        note.tags.removeAll { $0.id == tag.id }
        note.updatedAt = Date()
        SafePersistence.save(context, label: "removeTag")
    }

    /// 删除标签（从所有笔记中解除关联）。
    func deleteTag(_ tag: Tag, context: ModelContext) {
        for note in tag.notes {
            note.tags.removeAll { $0.id == tag.id }
        }
        context.delete(tag)
        SafePersistence.save(context, label: "deleteTag")
        booksVersion &+= 1
    }

    /// 重命名标签。
    func renameTag(_ tag: Tag, to newName: String, context: ModelContext) {
        let normalized = Tag.normalize(name: newName)
        guard !normalized.isEmpty, normalized != tag.id else { return }
        // 检查新名是否冲突
        var conflictDescriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.id == normalized }
        )
        conflictDescriptor.fetchLimit = 1
        if let _ = try? context.fetch(conflictDescriptor).first {
            // 冲突：合并到现有标签
            if let existing = try? context.fetch(conflictDescriptor).first, existing.id != tag.id {
                for note in tag.notes where !note.tags.contains(where: { $0.id == existing.id }) {
                    note.tags.append(existing)
                }
                deleteTag(tag, context: context)
                return
            }
        }
        tag.id = normalized
        tag.name = normalized
        SafePersistence.save(context, label: "renameTag")
    }

    func addBook(title: String, author: String?, context: ModelContext) {
        let book = Book(title: title, author: author)
        context.insert(book)
        SafePersistence.save(context, label: "addBook")
        booksVersion &+= 1
    }

    func addNote(to book: Book, highlight: String, userNote: String?, chapter: String?, location: String?, context: ModelContext) {
        let note = ReadingNote(
            book: book,
            chapter: chapter,
            highlight: highlight,
            userNote: userNote,
            location: location,
            sourceHash: UUID().uuidString
        )
        book.notes.append(note)
        book.updatedAt = Date()
        SafePersistence.save(context, label: "addNote")
        invalidateNotesCaches()
    }

    func randomNote() -> ReadingNote? {
        allNotes.randomElement()
    }

    func seedIfEmpty(context: ModelContext) {
        let descriptor = FetchDescriptor<Book>()
        let count = SafePersistence.fetchCount(context, descriptor, label: "seedIfEmpty")
        guard count == 0 else { return }

        let samples = SampleData.createSampleBooks()
        for book in samples {
            context.insert(book)
        }
        SafePersistence.save(context, label: "seedIfEmpty")
        booksVersion &+= 1
    }

    // MARK: - Data Management

    func exportAllAsMarkdown(context: ModelContext) -> String {
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let books = SafePersistence.fetch(context, descriptor, label: "exportAllAsMarkdown")
        return MarkdownExporter().exportAllBooks(books)
    }

    func storeURL(context: ModelContext) -> URL? {
        context.container.configurations.first?.url
    }

    // MARK: - Cache Invalidation

    private func invalidateAllCaches() {
        booksVersion &+= 1
    }

    /// 笔记级别失效：数量/统计/推荐排序变；search index 不变（文本不变）。
    private func invalidateNotesCaches() {
        invalidateAllCaches()
    }

    private func computeStats(from books: [Book]) -> LibraryStats {
        var noteCount = 0
        var thoughtCount = 0
        var unreviewedCount = 0

        for book in books {
            noteCount += book.notes.count
            for note in book.notes {
                if note.userNote?.isEmpty == false {
                    thoughtCount += 1
                }
                if !note.isReviewed {
                    unreviewedCount += 1
                }
            }
        }

        return LibraryStats(
            bookCount: books.count,
            noteCount: noteCount,
            thoughtCount: thoughtCount,
            unreviewedCount: unreviewedCount
        )
    }
}

struct SearchIndexEntry {
    let note: ReadingNote
    let haystack: String

    init(note: ReadingNote) {
        self.note = note
        haystack = Self.normalize([
            note.highlight,
            note.userNote ?? "",
            note.chapter ?? "",
            note.location ?? "",
            note.book?.title ?? "",
            note.book?.author ?? ""
        ].joined(separator: " "))
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SyncState {
    var isSyncing = false
    var progress: WeReadSyncProgress?
    var lastSyncedAt: Date?
    var lastMessage: String?
    var lastError: String?
}

struct LibraryStats {
    let bookCount: Int
    let noteCount: Int
    let thoughtCount: Int
    let unreviewedCount: Int
}

enum NoteKindFilter: String, CaseIterable, Identifiable {
    case all
    case highlights
    case thoughts
    case reviews

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "全部"
        case .highlights: return "划线"
        case .thoughts: return "有想法"
        case .reviews: return "书评"
        }
    }
}

enum NoteSortMode: String, CaseIterable, Identifiable {
    case createdDescending
    case importedDescending
    case chapterAscending
    case reviewDue

    var id: String { rawValue }

    var label: String {
        switch self {
        case .createdDescending: return "创建时间"
        case .importedDescending: return "导入时间"
        case .chapterAscending: return "章节顺序"
        case .reviewDue: return "复习优先"
        }
    }
}
