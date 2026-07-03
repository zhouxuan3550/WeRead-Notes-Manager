import SwiftUI

// MARK: - 字体系统重塑
//
// 设计目标：摆脱 SwiftUI "默认感"，每个文字都有自己的角色。
//
// 字体角色：
// - displayLarge:  28-34pt SF Pro Display Bold（首页 hero / 启动页）
// - displayMedium: 22-26pt SF Pro Display Semibold（section 标题）
// - title:         17-20pt SF Pro Text Semibold（卡片标题）
// - body:          15pt SF Pro Text Regular（正文）
// - bodyStrong:    15pt SF Pro Text Medium（按钮文字）
// - caption:       13pt SF Pro Text Regular（次要文字）
// - micro:         11pt SF Pro Text Medium UPPERCASE（标签 / 角标）
// - mono:          13pt SF Mono Regular（数字 / 时间）
// - serif:         17pt New York / Source Han Serif（中文引文）
//
// 字距规范：
// - displayLarge: -0.5（大字号字距收紧更精致）
// - displayMedium: -0.3
// - title: -0.2
// - body: 0
// - caption: 0.1
// - micro: 0.8 + uppercase

// MARK: - 字体角色

enum Typography {
    // MARK: Display
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .default)
    static let displayMedium = Font.system(size: 26, weight: .semibold, design: .default)
    static let displaySmall = Font.system(size: 22, weight: .semibold, design: .default)

    // MARK: Title
    static let title1 = Font.system(size: 20, weight: .semibold, design: .default)
    static let title2 = Font.system(size: 17, weight: .semibold, design: .default)
    static let title3 = Font.system(size: 15, weight: .semibold, design: .default)

    // MARK: Body
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let bodyStrong = Font.system(size: 15, weight: .medium, design: .default)
    static let bodyEmphasized = Font.system(size: 15, weight: .semibold, design: .default)

    // MARK: Caption / Micro
    static let caption = Font.system(size: 13, weight: .regular, design: .default)
    static let captionStrong = Font.system(size: 13, weight: .medium, design: .default)

    /// 微型标签 - 全大写 + 字距放宽
    static let micro = Font.system(size: 11, weight: .semibold, design: .default)

    /// 数字 / 时间 - 等宽
    static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoLarge = Font.system(size: 28, weight: .semibold, design: .monospaced)
    static let monoDisplay = Font.system(size: 48, weight: .bold, design: .monospaced)

    /// 衬线 - 中文引文 / 杂志风格
    static let serif = Font.system(size: 17, weight: .regular, design: .serif)
    static let serifTitle = Font.system(size: 24, weight: .semibold, design: .serif)
    static let serifItalic = Font.system(size: 17, weight: .regular, design: .serif).italic()

    /// 中文标题（如果系统装了 Source Han Serif）
    static let serifCN = Font.custom("SourceHanSerifSC-Regular", size: 17)

    /// 等宽数字（用于统计）
    static let numeric = Font.system(size: 32, weight: .bold, design: .rounded).monospacedDigit()
}

// MARK: - 字距常量

enum Tracking {
    static let displayLarge: CGFloat = -0.8
    static let displayMedium: CGFloat = -0.5
    static let title: CGFloat = -0.3
    static let body: CGFloat = 0
    static let caption: CGFloat = 0.1
    static let micro: CGFloat = 1.2
}

// MARK: - 行高

enum LineHeight {
    static let tight: CGFloat = 1.15
    static let standard: CGFloat = 1.45
    static let relaxed: CGFloat = 1.7
    static let loose: CGFloat = 1.9
}

// MARK: - View 扩展

extension View {
    /// 应用排版角色 + 字距
    func typography(_ font: Font, tracking: CGFloat = 0, lineHeight: CGFloat? = nil) -> some View {
        self.font(font)
            .tracking(tracking)
            .lineSpacing(lineHeight.map { ($0 - 1) * 16 } ?? 0)
    }

    /// 微型标签（全大写 + 字距）
    func microLabel() -> some View {
        self.font(Typography.micro)
            .tracking(Tracking.micro)
            .textCase(.uppercase)
    }

    /// 大标题（字距收紧）
    func displayText() -> some View {
        self.font(Typography.displayLarge)
            .tracking(Tracking.displayLarge)
    }

    /// 等宽数字
    func numericDisplay() -> some View {
        self.font(Typography.numeric)
            .monospacedDigit()
    }

    /// 中文衬线
    func serifText() -> some View {
        self.font(Typography.serifCN)
            .lineSpacing(LineHeight.standard)
    }
}

// MARK: - 文本样式预设

struct DisplayText: View {
    let text: String
    var size: CGFloat = 34
    var weight: Font.Weight = .bold

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .default))
            .tracking(-0.8)
    }
}

struct TitleText: View {
    let text: String
    var size: CGFloat = 17
    var weight: Font.Weight = .semibold

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .default))
            .tracking(-0.3)
    }
}

struct MicroLabel: View {
    let text: String
    var color: Color?
    @Environment(\.themePalette) private var palette

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(color ?? palette.textTertiary)
    }
}

struct SerifQuote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .regular, design: .serif))
            .lineSpacing(7)
            .tracking(0.2)
    }
}