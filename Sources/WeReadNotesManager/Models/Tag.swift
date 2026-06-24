import Foundation
import SwiftData
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@Model
final class Tag {
    @Attribute(.unique) var id: String
    var name: String
    /// 16 进制颜色字符串（如 "#5B8DEF"）；nil 表示未指定（用 accent color）
    var colorHex: String?
    var createdAt: Date
    /// 该标签下的笔记（多对多反关系）
    @Relationship(inverse: \ReadingNote.tags)
    var notes: [ReadingNote]

    init(
        id: String? = nil,
        name: String,
        colorHex: String? = nil,
        createdAt: Date = Date(),
        notes: [ReadingNote] = []
    ) {
        self.id = id ?? Tag.normalize(name: name)
        self.name = Tag.normalize(name: name)
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.notes = notes
    }

    /// 标签名归一化：trim + 去除内部空白 + lowercase，保证 "算法" / " 算法 " / "算 法" 视为同一标签。
    static func normalize(name raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.replacingOccurrences(
            of: "\\s+",
            with: "",
            options: .regularExpression
        )
        return collapsed
    }

    /// SwiftUI Color（懒加载）。注意：在 SwiftUI 视图体内调用须注意上下文，
    /// 优先用 `Tag.color(hex:)` 工具方法避免 @Model binding 推断冲突。
    var resolvedColor: Color {
        guard let hex = colorHex else { return .accentColor }
        return Color(hex: hex) ?? .accentColor
    }
}

extension Color {
    /// 简单十六进制颜色解析，支持 "#RRGGBB" 或 "RRGGBB"。
    init?(hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else {
            return nil
        }
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}