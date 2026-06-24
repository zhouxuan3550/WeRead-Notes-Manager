import Foundation
import SwiftData

@Model
final class ReadingNote {
    var id: UUID
    var chapter: String?
    var highlight: String
    var userNote: String?
    var location: String?
    var createdAt: Date?
    var importedAt: Date
    var updatedAt: Date
    var isFavorite: Bool
    var isReviewed: Bool
    var reviewCount: Int
    var lastReviewedAt: Date?
    var source: String
    var sourceID: String?
    var sourceURL: String?
    var noteKind: String?
    var sourceHash: String
    var book: Book?

    // MARK: - 软删除（Feature 1）
    var isDeleted: Bool = false
    var deletedAt: Date?

    // MARK: - 标签（Feature 3）
    var tags: [Tag] = []

    // MARK: - SRS 字段（Feature 5）
    var easeFactor: Double = 2.5
    var intervalDays: Int = 0
    var repetitions: Int = 0
    var nextReviewAt: Date?

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        chapter: String? = nil,
        highlight: String,
        userNote: String? = nil,
        location: String? = nil,
        createdAt: Date? = nil,
        importedAt: Date = Date(),
        updatedAt: Date = Date(),
        isFavorite: Bool = false,
        isReviewed: Bool = false,
        reviewCount: Int = 0,
        lastReviewedAt: Date? = nil,
        source: String = "manual",
        sourceID: String? = nil,
        sourceURL: String? = nil,
        noteKind: String = "highlight",
        sourceHash: String = "",
        tags: [Tag] = []
    ) {
        self.id = id
        self.book = book
        self.chapter = chapter
        self.highlight = highlight
        self.userNote = userNote
        self.location = location
        self.createdAt = createdAt
        self.importedAt = importedAt
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.isReviewed = isReviewed
        self.reviewCount = reviewCount
        self.lastReviewedAt = lastReviewedAt
        self.source = source
        self.sourceID = sourceID
        self.sourceURL = sourceURL
        self.noteKind = noteKind
        self.sourceHash = sourceHash
        self.tags = tags
    }
}
