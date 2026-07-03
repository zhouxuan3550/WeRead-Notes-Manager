import Foundation
import SwiftData

/// 用户自定义分享卡片预设（未来 Pro 功能）。
@Model
final class ShareCardPreset {
    @Attribute(.unique) var id: UUID
    var name: String
    var templateID: String
    var primaryColorHex: String
    var backgroundColorHex: String
    var fontName: String?
    var showBookTitle: Bool
    var showAuthor: Bool
    var showWatermark: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        templateID: String,
        primaryColorHex: String,
        backgroundColorHex: String,
        fontName: String? = nil,
        showBookTitle: Bool = true,
        showAuthor: Bool = true,
        showWatermark: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.templateID = templateID
        self.primaryColorHex = primaryColorHex
        self.backgroundColorHex = backgroundColorHex
        self.fontName = fontName
        self.showBookTitle = showBookTitle
        self.showAuthor = showAuthor
        self.showWatermark = showWatermark
        self.createdAt = createdAt
    }
}
