import Foundation
import SwiftData

@Model
final class BookSummary {
    var id: UUID
    var book: Book?
    /// 总结内容（AI 生成）
    var content: String
    /// 用户追问 Q&A（JSON 字符串；可选）
    var followUps: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        content: String,
        followUps: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.book = book
        self.content = content
        self.followUps = followUps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}