import Foundation
import SwiftData

@Model
final class WritingCard {
    @Attribute(.unique) var id: UUID
    var noteID: UUID
    var bookTitle: String?
    var highlight: String
    var coreIdea: String
    var scenarios: [String]
    var quote: String
    var extensions: [String]
    var counter: String
    var example: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        noteID: UUID,
        bookTitle: String? = nil,
        highlight: String,
        coreIdea: String,
        scenarios: [String],
        quote: String,
        extensions: [String],
        counter: String,
        example: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.noteID = noteID
        self.bookTitle = bookTitle
        self.highlight = highlight
        self.coreIdea = coreIdea
        self.scenarios = scenarios
        self.quote = quote
        self.extensions = extensions
        self.counter = counter
        self.example = example
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
