import Foundation
import SwiftUI

// MARK: - 高亮工具
//
// 把字符串里的查询词用主题强调色高亮。
// 用法：
//   HighlightedText(text: "今天天气真好", query: "天气")
//
// 设计：把文本按 token 切片，拼成多个 Text（普通 + 高亮），
// 简单可靠，避开 AttributedString 索引 API 的兼容陷阱。

struct HighlightedText: View {
    let text: String
    let query: String
    var font: Font = .system(size: 15)
    var color: Color? = nil
    var highlightColor: Color? = nil
    var highlightFont: Font? = nil
    var lineLimit: Int? = nil

    @Environment(\.themePalette) private var palette

    private var tokens: [String] {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    private var resolvedNormal: Color {
        color ?? palette.textPrimary
    }

    private var resolvedHighlight: Color {
        highlightColor ?? palette.accent
    }

    var body: some View {
        let segments = makeSegments()
        return segments.reduce(Text("")) { acc, seg in
            switch seg {
            case .normal(let s):
                return acc + Text(s).font(font).foregroundStyle(resolvedNormal)
            case .highlight(let s):
                return acc + Text(s)
                    .font(highlightFont ?? font.weight(.semibold))
                    .foregroundStyle(resolvedHighlight)
                    .underline(true, color: resolvedHighlight.opacity(0.6))
            }
        }
        .lineLimit(lineLimit)
    }

    // MARK: - 切片逻辑

    private enum Segment {
        case normal(String)
        case highlight(String)
    }

    private func makeSegments() -> [Segment] {
        let toks = tokens
        guard !toks.isEmpty else { return [.normal(text)] }

        // 用 NSString 扫描，定位所有命中区间
        let nsText = text as NSString
        let lowerText = text.lowercased() as NSString
        var hits: [NSRange] = []

        for token in toks {
            let lower = token.lowercased()
            var searchRange = NSRange(location: 0, length: lowerText.length)
            while searchRange.location < lowerText.length {
                let r = lowerText.range(of: lower, options: [], range: searchRange)
                if r.location == NSNotFound { break }
                hits.append(r)
                let next = r.location + r.length
                searchRange = NSRange(location: next, length: lowerText.length - next)
            }
        }

        // 合并/排序
        hits.sort { $0.location < $1.location }
        var merged: [NSRange] = []
        for hit in hits {
            if let last = merged.last,
               hit.location <= last.location + last.length {
                let end = max(last.location + last.length, hit.location + hit.length)
                merged[merged.count - 1] = NSRange(location: last.location, length: end - last.location)
            } else {
                merged.append(hit)
            }
        }

        // 切成片段
        var segments: [Segment] = []
        var cursor = 0
        for hit in merged {
            if hit.location > cursor {
                let s = nsText.substring(with: NSRange(location: cursor, length: hit.location - cursor))
                segments.append(.normal(s))
            }
            let highlighted = nsText.substring(with: hit)
            segments.append(.highlight(highlighted))
            cursor = hit.location + hit.length
        }
        if cursor < nsText.length {
            let s = nsText.substring(with: NSRange(location: cursor, length: nsText.length - cursor))
            segments.append(.normal(s))
        }

        return segments
    }
}