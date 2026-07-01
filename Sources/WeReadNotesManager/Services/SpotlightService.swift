import Foundation
import CoreSpotlight
import SwiftData
import UniformTypeIdentifiers

// MARK: - Spotlight 索引服务
//
// 把笔记同步到系统 Spotlight，让用户在 macOS 顶部搜索
// 就能直接命中笔记内容（书名/章节/划线/想法/标签）。
//
// 索引策略：
// - 每次笔记增删改时增量更新
// - 启动时全量重建（解决数据漂移）
// - uniqueIdentifier = "wrm-note-<UUID>"

enum SpotlightService {
    static let domain = "com.weread.notesmanager.notes"

    /// 索引所有笔记。
    @MainActor
    static func indexAll(books: [Book]) async {
        let items = books.flatMap { book -> [CSSearchableItem] in
            book.notes.filter { !$0.isDeleted }.map { note in
                makeItem(for: note, in: book)
            }
        }

        guard !items.isEmpty else {
            // 清空索引
            try? await CSSearchableIndex.default().deleteAllSearchableItems()
            return
        }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
        } catch {
            AppLog.error("Spotlight 索引失败", error: error, category: .general)
        }
    }

    /// 索引单条笔记。
    @MainActor
    static func index(note: ReadingNote) async {
        guard !note.isDeleted, let book = note.book else { return }
        let item = makeItem(for: note, in: book)
        try? await CSSearchableIndex.default().indexSearchableItems([item])
    }

    /// 移除单条笔记的索引。
    @MainActor
    static func remove(noteID: UUID) async {
        try? await CSSearchableIndex.default()
            .deleteSearchableItems(withIdentifiers: ["wrm-note-\(noteID.uuidString)"])
    }

    /// 全量清空。
    @MainActor
    static func clearAll() async {
        try? await CSSearchableIndex.default().deleteAllSearchableItems()
    }

    // MARK: - 构造

    private static func makeItem(for note: ReadingNote, in book: Book) -> CSSearchableItem {
        let attrSet = CSSearchableItemAttributeSet(contentType: .text)

        attrSet.title = String(note.highlight.prefix(100))
        attrSet.contentDescription = [
            note.userNote,
            book.title,
            note.chapter
        ].compactMap { $0 }.joined(separator: "\n")

        attrSet.creator = book.author
        attrSet.keywords = note.tags.map(\.name) + [book.title, note.chapter].compactMap { $0 }
        attrSet.contentCreationDate = note.createdAt
        attrSet.contentModificationDate = note.updatedAt

        // 缩略图：书籍封面
        if let urlString = book.coverURL, let url = URL(string: urlString) {
            attrSet.thumbnailURL = url
        }

        let item = CSSearchableItem(
            uniqueIdentifier: "wrm-note-\(note.id.uuidString)",
            domainIdentifier: domain,
            attributeSet: attrSet
        )

        return item
    }
}

// MARK: - AppLog stub removed — using existing AppLog from Utilities/AppError.swift