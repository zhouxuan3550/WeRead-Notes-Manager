import Foundation
import SwiftData

struct ExportService {
    let modelContext: ModelContext

    func exportFavorites() -> String {
        let descriptor = FetchDescriptor<ReadingNote>(
            predicate: #Predicate { $0.isFavorite }
        )
        let notes = SafePersistence.fetch(modelContext, descriptor, label: "exportFavorites")
        return MarkdownExporter().exportNotes(notes)
    }

    func exportUnreviewed() -> String {
        let descriptor = FetchDescriptor<ReadingNote>(
            predicate: #Predicate { !$0.isReviewed }
        )
        let notes = SafePersistence.fetch(modelContext, descriptor, label: "exportUnreviewed")
        return MarkdownExporter().exportNotes(notes)
    }

    func exportBook(_ book: Book) -> String {
        return MarkdownExporter().exportNotes(book.notes, bookTitle: book.title)
    }

    func exportAll() -> String {
        let descriptor = FetchDescriptor<Book>()
        let books = SafePersistence.fetch(modelContext, descriptor, label: "exportAll")
        return MarkdownExporter().exportAllBooks(books)
    }

    func exportNotes(_ notes: [ReadingNote]) -> String {
        return MarkdownExporter().exportNotes(notes)
    }
}
