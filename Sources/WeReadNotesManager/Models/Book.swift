import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var author: String?
    var coverPath: String?
    var coverURL: String?
    var createdAt: Date
    var updatedAt: Date
    var lastImportedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \ReadingNote.book)
    var notes: [ReadingNote]

    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        coverPath: String? = nil,
        coverURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastImportedAt: Date? = nil,
        notes: [ReadingNote] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.coverPath = coverPath
        self.coverURL = coverURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastImportedAt = lastImportedAt
        self.notes = notes
    }
}
