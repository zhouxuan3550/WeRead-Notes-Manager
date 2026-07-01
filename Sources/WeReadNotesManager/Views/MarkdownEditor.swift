import SwiftUI

// MARK: - Markdown 实时编辑器
//
// 支持：
// - # / ## / ### 标题
// - **粗体** *斜体* ~~删除线~~
// - `行内代码`
// - > 引用
// - - / 1. 列表
// - [text](url) 链接
// - ```代码块```
//
// 提供两种模式：编辑 + 实时预览 / 纯编辑

struct MarkdownEditor: View {
    @Binding var text: String
    var font: Font = .system(size: 14)
    var minHeight: CGFloat = 80

    @State private var isPreviewMode = false

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if isPreviewMode {
                MarkdownPreviewView(text: text, font: font)
                    .frame(minHeight: minHeight, alignment: .topLeading)
                    .padding(10)
                    .background(palette.surface.opacity(0.4))
            } else {
                TextEditor(text: $text)
                    .font(font)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: minHeight)
                    .background(palette.surface.opacity(0.4))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Group {
                toolButton("H1", weight: .bold) { wrapSelection(prefix: "# ") }
                toolButton("H2", weight: .semibold) { wrapSelection(prefix: "## ") }
                toolButton("B", weight: .bold) { wrap(token: "**") }
                toolButton("I", weight: .regular) { wrap(token: "*") }
                toolButton("S", weight: .regular) { wrap(token: "~~") }
                toolButton("</>", weight: .medium) { wrap(token: "`") }
                toolButton("\"", weight: .regular) { insertAtLineStart("> ") }
                toolButton("•", weight: .regular) { insertAtLineStart("- ") }
                toolButton("1.", weight: .regular) { insertAtLineStart("1. ") }
                toolButton("🔗", weight: .regular) { insertLink() }
            }

            Spacer()

            Toggle(isOn: $isPreviewMode) {
                Label("预览", systemImage: "eye")
                    .font(.system(size: 10))
            }
            .toggleStyle(.button)
            .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(palette.surface.opacity(0.7))
    }

    private func toolButton(_ label: String, weight: Font.Weight, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: weight))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.textPrimary)
    }

    // MARK: - 文本操作

    private func wrap(token: String) {
        text += token
    }

    private func wrapSelection(prefix: String) {
        text = prefix + text
    }

    private func insertAtLineStart(_ prefix: String) {
        text = prefix + text
    }

    private func insertLink() {
        text += "[text](url)"
    }
}

// MARK: - Markdown 实时预览

struct MarkdownPreviewView: View {
    let text: String
    var font: Font = .system(size: 14)

    @Environment(\.themePalette) private var palette

    var body: some View {
        let blocks = MarkdownParser.parse(text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
            if text.isEmpty {
                Text("（空）")
                    .foregroundStyle(palette.textTertiary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(.system(size: headingSize(level: level), weight: .bold))
                .foregroundStyle(palette.textPrimary)
        case .paragraph(let text):
            Text(attributedString(from: text))
                .font(font)
                .foregroundStyle(palette.textPrimary)
        case .quote(let text):
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(palette.accent)
                    .frame(width: 3)
                Text(text)
                    .font(font)
                    .foregroundStyle(palette.textSecondary)
                    .italic()
            }
        case .code(let text):
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(palette.surfaceElevated)
                )
        case .listItem(let text):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .foregroundStyle(palette.accent)
                Text(attributedString(from: text))
                    .font(font)
                    .foregroundStyle(palette.textPrimary)
            }
        }
    }

    private func headingSize(level: Int) -> CGFloat {
        switch level {
        case 1: return 22
        case 2: return 18
        case 3: return 16
        default: return 14
        }
    }

    private func attributedString(from text: String) -> AttributedString {
        var attr = AttributedString(text)
        attr = applyBold(attr)
        attr = applyItalic(attr)
        attr = applyStrikethrough(attr)
        attr = applyInlineCode(attr)
        attr = applyLink(attr)
        return attr
    }

    private func applyBold(_ attr: AttributedString) -> AttributedString {
        var result = attr
        for range in findMatches(in: result, pattern: "\\*\\*(.+?)\\*\\*").reversed() {
            result[range].font = .system(size: 14, weight: .bold)
        }
        return result
    }

    private func applyItalic(_ attr: AttributedString) -> AttributedString {
        var result = attr
        for range in findMatches(in: result, pattern: "\\*(.+?)\\*").reversed() {
            result[range].font = .system(size: 14, weight: .regular).italic()
        }
        return result
    }

    private func applyStrikethrough(_ attr: AttributedString) -> AttributedString {
        var result = attr
        for range in findMatches(in: result, pattern: "~~(.+?)~~").reversed() {
            result[range].strikethroughStyle = .single
        }
        return result
    }

    private func applyInlineCode(_ attr: AttributedString) -> AttributedString {
        var result = attr
        for range in findMatches(in: result, pattern: "`(.+?)`").reversed() {
            result[range].font = .system(size: 13, design: .monospaced)
            result[range].backgroundColor = palette.accentSoft
        }
        return result
    }

    private func applyLink(_ attr: AttributedString) -> AttributedString {
        var result = attr
        for range in findMatches(in: result, pattern: "\\[(.+?)\\]\\((.+?)\\)").reversed() {
            result[range].foregroundColor = palette.accent
            result[range].underlineStyle = .single
        }
        return result
    }

    /// 返回所有匹配区间（AttributedString.Index 范围）
    private func findMatches(in attr: AttributedString, pattern: String) -> [Range<AttributedString.Index>] {
        let chars = attr.characters
        let source = String(chars)
        let totalLength = chars.count
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(location: 0, length: (source as NSString).length)
        let matches = regex.matches(in: source, range: nsRange)

        var result: [Range<AttributedString.Index>] = []
        for m in matches {
            let lowerOffset = m.range.location
            let upperOffset = m.range.location + m.range.length
            guard lowerOffset >= 0, upperOffset <= totalLength else { continue }
            if let start = chars.index(chars.startIndex, offsetBy: lowerOffset, limitedBy: chars.endIndex),
               let end = chars.index(chars.startIndex, offsetBy: upperOffset, limitedBy: chars.endIndex) {
                result.append(start..<end)
            }
        }
        return result
    }
}

// MARK: - Markdown 块模型

enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case quote(String)
    case code(String)
    case listItem(String)
}

enum MarkdownParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)

        var inCodeBlock = false
        var codeBuffer: [String] = []
        var paragraphBuffer: [String] = []

        func flushParagraph() {
            if !paragraphBuffer.isEmpty {
                let text = paragraphBuffer.joined(separator: " ")
                blocks.append(.paragraph(text))
                paragraphBuffer.removeAll()
            }
        }

        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    blocks.append(.code(codeBuffer.joined(separator: "\n")))
                    codeBuffer.removeAll()
                    inCodeBlock = false
                } else {
                    flushParagraph()
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBuffer.append(line)
                continue
            }

            if line.isEmpty {
                flushParagraph()
                continue
            }

            if line.hasPrefix("# ") {
                flushParagraph()
                blocks.append(.heading(level: 1, text: String(line.dropFirst(2))))
            } else if line.hasPrefix("## ") {
                flushParagraph()
                blocks.append(.heading(level: 2, text: String(line.dropFirst(3))))
            } else if line.hasPrefix("### ") {
                flushParagraph()
                blocks.append(.heading(level: 3, text: String(line.dropFirst(4))))
            } else if line.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.quote(String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                blocks.append(.listItem(String(line.dropFirst(2))))
            } else if line.hasPrefix("1. ") {
                flushParagraph()
                blocks.append(.listItem(String(line.dropFirst(3))))
            } else {
                paragraphBuffer.append(line)
            }
        }

        flushParagraph()
        if inCodeBlock && !codeBuffer.isEmpty {
            blocks.append(.code(codeBuffer.joined(separator: "\n")))
        }

        return blocks
    }
}