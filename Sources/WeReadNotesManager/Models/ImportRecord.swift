import Foundation
import SwiftData

@Model
final class ImportRecord {
    var id: UUID
    var fileName: String
    var fileType: String
    var source: String
    var importedAt: Date
    var booksCreated: Int
    var notesCreated: Int
    var duplicatesSkipped: Int
    var failedCount: Int
    var message: String?

    init(
        id: UUID = UUID(),
        fileName: String,
        fileType: String,
        source: String,
        importedAt: Date = Date(),
        booksCreated: Int = 0,
        notesCreated: Int = 0,
        duplicatesSkipped: Int = 0,
        failedCount: Int = 0,
        message: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.fileType = fileType
        self.source = source
        self.importedAt = importedAt
        self.booksCreated = booksCreated
        self.notesCreated = notesCreated
        self.duplicatesSkipped = duplicatesSkipped
        self.failedCount = failedCount
        self.message = message
    }
}
