import Foundation

protocol NoteImporter {
    var sourceName: String { get }
    var supportedFileExtensions: [String] { get }
    func canImport(fileURL: URL) -> Bool
    func importNotes(from fileURL: URL) throws -> ImportResult
}

struct ImportResult {
    let books: [ImportedBook]
    let notes: [ImportedNote]
    let failures: [ImportFailure]
}

struct ImportedBook {
    let title: String
    let author: String?
    let coverURL: String?
}

struct ImportedNote {
    let bookTitle: String
    let author: String?
    let chapter: String?
    let highlight: String
    let userNote: String?
    let location: String?
    let createdAt: Date?
    let source: String
    let sourceID: String?
    let sourceURL: String?
    let noteKind: String

    init(
        bookTitle: String,
        author: String?,
        chapter: String?,
        highlight: String,
        userNote: String?,
        location: String?,
        createdAt: Date?,
        source: String,
        sourceID: String?,
        sourceURL: String? = nil,
        noteKind: String = "highlight"
    ) {
        self.bookTitle = bookTitle
        self.author = author
        self.chapter = chapter
        self.highlight = highlight
        self.userNote = userNote
        self.location = location
        self.createdAt = createdAt
        self.source = source
        self.sourceID = sourceID
        self.sourceURL = sourceURL
        self.noteKind = noteKind
    }
}

struct ImportFailure {
    let lineNumber: Int?
    let rawText: String?
    let reason: String
}
