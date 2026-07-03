import Foundation
import SwiftData

@Model
final class TopicCluster {
    @Attribute(.unique) var id: UUID
    var name: String
    var summary: String?
    var noteIDs: [UUID]
    var keywords: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        summary: String? = nil,
        noteIDs: [UUID],
        keywords: [String],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.noteIDs = noteIDs
        self.keywords = keywords
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
