import Foundation

struct WeReadSyncProgress {
    let current: Int
    let total: Int
    let bookTitle: String

    var fractionCompleted: Double {
        guard total > 0 else { return 0 }
        return min(Double(current) / Double(total), 1)
    }

    var title: String {
        if total <= 1 {
            return bookTitle
        }
        return "正在同步 \(current)/\(total)"
    }

    var detail: String {
        bookTitle
    }
}

struct WeReadAPIService {
    private let apiKey: String
    private let skillVersion = "1.0.3"
    private let gatewayURL = URL(string: "https://i.weread.qq.com/api/agent/gateway")!

    init(apiKey: String) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 流式版本：返回 `AsyncThrowingStream`，逐步推送进度事件和最终结果。
    ///
    /// 用法：
    /// ```swift
    /// for try await update in apiService.fetchImportResultStream() {
    ///     switch update {
    ///     case .progress(let p): print(p)
    ///     case .completed(let r): handle(r)
    ///     }
    /// }
    /// ```
    func fetchImportResultStream() -> AsyncThrowingStream<ImportStreamUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !apiKey.isEmpty else {
                        throw WeReadAPIError.missingAPIKey
                    }

                    continuation.yield(.progress(WeReadSyncProgress(current: 0, total: 1, bookTitle: "正在读取笔记本...")))
                    let notebookBooks = try await self.fetchNotebookBooks()
                    var importedBooks: [String: ImportedBook] = [:]
                    var importedNotes: [ImportedNote] = []
                    var failures: [ImportFailure] = []

                    if notebookBooks.isEmpty {
                        continuation.yield(.progress(WeReadSyncProgress(current: 1, total: 1, bookTitle: "没有找到可同步的笔记")))
                    }

                    for (index, notebookBook) in notebookBooks.enumerated() {
                        try Task.checkCancellation()
                        continuation.yield(.progress(WeReadSyncProgress(
                            current: index + 1,
                            total: notebookBooks.count,
                            bookTitle: "《\(notebookBook.title)》"
                        )))

                        let book = ImportedBook(
                            title: notebookBook.title,
                            author: notebookBook.author,
                            coverURL: notebookBook.coverURL
                        )
                        importedBooks[self.bookKey(title: book.title, author: book.author)] = book

                        do {
                            let notes = try await self.fetchNotes(for: notebookBook)
                            importedNotes.append(contentsOf: notes)
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            failures.append(ImportFailure(
                                lineNumber: nil,
                                rawText: notebookBook.title,
                                reason: "同步《\(notebookBook.title)》失败：\(error.localizedDescription)"
                            ))
                        }
                    }

                    continuation.yield(.completed(ImportResult(
                        books: Array(importedBooks.values),
                        notes: importedNotes,
                        failures: failures
                    )))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    AppLog.error("WeReadAPI.fetchImportResultStream 失败", error: error, category: .network)
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 旧版同步接口，保留以兼容现存调用方。
    @available(*, deprecated, message: "Use fetchImportResultStream() instead")
    func fetchImportResult(progress: @escaping (WeReadSyncProgress) -> Void = { _ in }) async throws -> ImportResult {
        var finalResult: ImportResult?
        for try await update in fetchImportResultStream() {
            switch update {
            case .progress(let p): progress(p)
            case .completed(let r): finalResult = r
            }
        }
        guard let r = finalResult else {
            throw WeReadAPIError.invalidResponse
        }
        return r
    }
}

/// 流式事件：进度或最终结果。
enum ImportStreamUpdate {
    case progress(WeReadSyncProgress)
    case completed(ImportResult)
}

private extension WeReadAPIService {
    struct NotebookBook {
        let bookId: String
        let title: String
        let author: String?
        let coverURL: String?
        let noteCount: Int
        let reviewCount: Int
        let bookmarkCount: Int
        let sort: Int?
    }

    func fetchNotebookBooks() async throws -> [NotebookBook] {
        var books: [NotebookBook] = []
        var lastSort: Int?

        while true {
            var parameters: [String: Any] = ["count": 100]
            if let lastSort {
                parameters["lastSort"] = lastSort
            }

            let response = try await post(apiName: "/user/notebooks", parameters: parameters)
            let items = response["books"] as? [[String: Any]] ?? []
            books.append(contentsOf: items.compactMap(parseNotebookBook))

            try Task.checkCancellation()

            let hasMore = intValue(response["hasMore"]) == 1
            guard hasMore, let nextSort = items.compactMap({ intValue($0["sort"]) }).last else {
                break
            }
            if nextSort == lastSort {
                break
            }
            lastSort = nextSort
        }

        return books.filter { $0.noteCount > 0 || $0.reviewCount > 0 }
    }

    func fetchNotes(for book: NotebookBook) async throws -> [ImportedNote] {
        async let bookmarkNotes = fetchBookmarkNotes(for: book)
        async let reviewNotes = fetchReviewNotes(for: book)
        return try await merge(bookmarkNotes: bookmarkNotes, reviewNotes: reviewNotes, book: book)
    }

    func fetchBookmarkNotes(for book: NotebookBook) async throws -> [ImportedNote] {
        guard book.noteCount > 0 else { return [] }

        let response = try await post(apiName: "/book/bookmarklist", parameters: ["bookId": book.bookId])
        let chapters = chapterMap(from: response["chapters"] as? [[String: Any]] ?? [])
        let items = response["updated"] as? [[String: Any]] ?? []

        return items.compactMap { item in
            guard let highlight = stringValue(item["markText"])?.trimmedNonEmpty else {
                return nil
            }

            let chapterUid = stringValue(item["chapterUid"])
            let range = stringValue(item["range"])
            let sourceID = firstNonEmpty(
                stringValue(item["bookmarkId"]).map { "bookmark:\($0)" },
                range.map { "bookmark:\(book.bookId):\($0)" }
            )

            return ImportedNote(
                bookTitle: book.title,
                author: book.author,
                chapter: chapterUid.flatMap { chapters[$0] },
                highlight: highlight,
                userNote: nil,
                location: range,
                createdAt: dateFromUnix(item["createTime"]),
                source: "weread_skill",
                sourceID: sourceID,
                sourceURL: deepLink(bookId: book.bookId, chapterUid: chapterUid, range: range),
                noteKind: "highlight"
            )
        }
    }

    func fetchReviewNotes(for book: NotebookBook) async throws -> [ImportedNote] {
        guard book.reviewCount > 0 else { return [] }

        var notes: [ImportedNote] = []
        var synckey = 0

        while true {
            let response = try await post(
                apiName: "/review/list/mine",
                parameters: ["bookid": book.bookId, "count": 100, "synckey": synckey]
            )

            let wrappers = response["reviews"] as? [[String: Any]] ?? []
            notes.append(contentsOf: wrappers.compactMap { wrapper in
                guard let review = wrapper["review"] as? [String: Any],
                      let content = stringValue(review["content"])?.trimmedNonEmpty else {
                    return nil
                }

                let abstract = firstNonEmpty(
                    stringValue(review["abstract"]),
                    stringValue(review["contextAbstract"])
                )
                let chapter = firstNonEmpty(
                    stringValue(review["chapterName"]),
                    stringValue(review["chapterTitle"])
                )
                let reviewId = firstNonEmpty(
                    stringValue(review["reviewId"]),
                    stringValue(wrapper["reviewId"])
                )

                return ImportedNote(
                    bookTitle: book.title,
                    author: book.author,
                    chapter: chapter,
                    highlight: abstract ?? content,
                    userNote: abstract == nil ? nil : content,
                    location: stringValue(review["range"]),
                    createdAt: dateFromUnix(review["createTime"]),
                    source: "weread_skill",
                    sourceID: reviewId.map { "review:\($0)" },
                    sourceURL: deepLink(
                        bookId: book.bookId,
                        chapterUid: stringValue(review["chapterUid"]),
                        range: stringValue(review["range"])
                    ),
                    noteKind: abstract == nil ? "review" : "thought"
                )
            })

            try Task.checkCancellation()

            let hasMore = intValue(response["hasMore"]) == 1
            guard hasMore, let nextSynckey = intValue(response["synckey"]), nextSynckey != synckey else {
                break
            }
            synckey = nextSynckey
        }

        return notes
    }

    func post(apiName: String, parameters: [String: Any]) async throws -> [String: Any] {
        var body = parameters
        body["api_name"] = apiName
        body["skill_version"] = skillVersion

        let payload = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: gatewayURL)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw WeReadAPIError.network
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WeReadAPIError.invalidResponse
        }

        if let upgradeInfo = json["upgrade_info"] as? [String: Any],
           let message = stringValue(upgradeInfo["message"]) {
            throw WeReadAPIError.upgradeRequired(message)
        }

        if let errcode = intValue(json["errcode"]), errcode != 0 {
            let message = firstNonEmpty(
                stringValue(json["errmsg"]),
                stringValue(json["message"]),
                "微信读书接口返回错误：\(errcode)"
            ) ?? "微信读书接口返回错误：\(errcode)"
            throw WeReadAPIError.server(message)
        }

        return json
    }

    func parseNotebookBook(_ item: [String: Any]) -> NotebookBook? {
        let nestedBook = item["book"] as? [String: Any]
        guard let bookId = firstNonEmpty(stringValue(item["bookId"]), stringValue(nestedBook?["bookId"])),
              let title = firstNonEmpty(stringValue(nestedBook?["title"]), stringValue(item["title"])) else {
            return nil
        }

        return NotebookBook(
            bookId: bookId,
            title: title,
            author: stringValue(nestedBook?["author"]),
            coverURL: stringValue(nestedBook?["cover"]),
            noteCount: intValue(item["noteCount"]) ?? 0,
            reviewCount: intValue(item["reviewCount"]) ?? 0,
            bookmarkCount: intValue(item["bookmarkCount"]) ?? 0,
            sort: intValue(item["sort"])
        )
    }

    func merge(bookmarkNotes: [ImportedNote], reviewNotes: [ImportedNote], book: NotebookBook) -> [ImportedNote] {
        var notes = bookmarkNotes
        var indexByRange: [String: Int] = [:]

        for (index, note) in notes.enumerated() {
            if let location = note.location, !location.isEmpty {
                indexByRange[location] = index
            }
        }

        for review in reviewNotes {
            guard let location = review.location,
                  let index = indexByRange[location],
                  let userNote = review.userNote?.trimmedNonEmpty else {
                notes.append(review)
                continue
            }

            let bookmark = notes[index]
            let mergedUserNote = firstNonEmpty(bookmark.userNote, userNote).map { existing in
                if existing == userNote {
                    return existing
                }
                if let oldNote = bookmark.userNote?.trimmedNonEmpty {
                    return "\(oldNote)\n\n\(userNote)"
                }
                return userNote
            }

            notes[index] = ImportedNote(
                bookTitle: bookmark.bookTitle,
                author: bookmark.author,
                chapter: firstNonEmpty(bookmark.chapter, review.chapter),
                highlight: bookmark.highlight,
                userNote: mergedUserNote,
                location: bookmark.location,
                createdAt: bookmark.createdAt ?? review.createdAt,
                source: bookmark.source,
                sourceID: "merged:\(book.bookId):\(location)",
                sourceURL: bookmark.sourceURL ?? review.sourceURL,
                noteKind: "highlight_thought"
            )
        }

        return notes
    }

    func deepLink(bookId: String, chapterUid: String?, range: String?) -> String {
        guard let chapterUid, let range,
              let separator = range.firstIndex(of: "-") else {
            return "weread://reading?bId=\(bookId)"
        }
        let start = String(range[..<separator])
        let end = String(range[range.index(after: separator)...])
        return "weread://bestbookmark?bookId=\(bookId)&chapterUid=\(chapterUid)&rangeStart=\(start)&rangeEnd=\(end)"
    }

    func chapterMap(from chapters: [[String: Any]]) -> [String: String] {
        var map: [String: String] = [:]
        for chapter in chapters {
            guard let chapterUid = stringValue(chapter["chapterUid"]),
                  let title = stringValue(chapter["title"]) else {
                continue
            }
            map[chapterUid] = title
        }
        return map
    }

    func bookKey(title: String, author: String?) -> String {
        "\(title.normalizedForHash())|\((author ?? "").normalizedForHash())"
    }

    func dateFromUnix(_ value: Any?) -> Date? {
        guard let timestamp = intValue(value), timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    func firstNonEmpty(_ values: String?...) -> String? {
        values.compactMap { $0?.trimmedNonEmpty }.first
    }

    func stringValue(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as Int:
            return String(value)
        case let value as Int64:
            return String(value)
        case let value as Double:
            return value.rounded() == value ? String(Int(value)) : String(value)
        default:
            return nil
        }
    }

    func intValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as Int64:
            return Int(value)
        case let value as Double:
            return Int(value)
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }
}

enum WeReadAPIError: LocalizedError {
    case missingAPIKey
    case network
    case invalidResponse
    case server(String)
    case upgradeRequired(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先填写微信读书 API Key。"
        case .network:
            return "无法连接微信读书接口，请稍后重试。"
        case .invalidResponse:
            return "微信读书接口返回了无法识别的数据。"
        case .server(let message):
            return message
        case .upgradeRequired(let message):
            return message
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
