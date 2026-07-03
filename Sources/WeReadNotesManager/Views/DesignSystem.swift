import SwiftUI

// MARK: - 设计系统
//
// 设计原则：
// - 颜色/间距/圆角/阴影/动画均为统一 token
// - 颜色 token 通过 @Environment(\.themePalette) 注入主题
// - 向下兼容：原 DesignSystem.Colors.* 仍然可用，但改为读取 theme

struct DesignSystem {
    // MARK: - 间距系统（保持不变）
    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - 圆角系统
    struct CornerRadius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 14
    }

    // MARK: - 阴影系统
    struct Shadows {
        static let sm = Shadow(color: .black.opacity(0.02), radius: 1, x: 0, y: 0)
        static let md = Shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        static let lg = Shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        static let xl = Shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - 动画系统（保持不变）
    struct Animation {
        static let fast = SwiftUI.Animation.spring(response: 0.20, dampingFraction: 0.88)
        static let `default` = SwiftUI.Animation.spring(response: 0.30, dampingFraction: 0.85)
        static let slow = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.82)
    }

    // MARK: - 向下兼容的色板（已废弃，请改用 ThemePalette）
    @available(*, deprecated, message: "Use environment(\\.themePalette) instead")
    struct Colors {
        static var background: Color { ThemePalette.midnight.background }
        static var surface: Color { ThemePalette.midnight.surface }
        static var surfaceElevated: Color { ThemePalette.midnight.surfaceElevated }
        static var primary: Color { ThemePalette.midnight.accent }
        static var primarySoft: Color { ThemePalette.midnight.accentSoft }
        static var accent: Color { ThemePalette.midnight.accent }
        static var accentSoft: Color { ThemePalette.midnight.accentSoft }
        static var success: Color { ThemePalette.midnight.success }
        static var warning: Color { ThemePalette.midnight.warning }
        static var error: Color { ThemePalette.midnight.error }
        static var textPrimary: Color { ThemePalette.midnight.textPrimary }
        static var textSecondary: Color { ThemePalette.midnight.textSecondary }
        static var textTertiary: Color { ThemePalette.midnight.textTertiary }
        static var borderSubtle: Color { ThemePalette.midnight.borderSubtle }
        static var borderMedium: Color { ThemePalette.midnight.borderMedium }
        static var borderStrong: Color { ThemePalette.midnight.borderStrong }
        static var overlay: Color { Color.black.opacity(0.35) }
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - 字体系统（保持兼容 + 增加衬线/等宽）

extension Font {
    static let display = Font.system(size: 34, weight: .bold)
    static let title1 = Font.system(size: 28, weight: .bold)
    static let title2 = Font.system(size: 22, weight: .semibold)
    static let title3 = Font.system(size: 18, weight: .semibold)

    static let body = Font.system(size: 15, weight: .regular)
    static let bodyStrong = Font.system(size: 15, weight: .medium)
    static let bodyBold = Font.system(size: 15, weight: .semibold)

    static let caption = Font.system(size: 13, weight: .regular)
    static let captionStrong = Font.system(size: 13, weight: .medium)
    static let captionBold = Font.system(size: 13, weight: .semibold)

    static let small = Font.system(size: 11, weight: .regular)
    static let smallStrong = Font.system(size: 11, weight: .medium)

    // 新增：等宽 / 衬线 / 杂志
    static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoStrong = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let serifTitle = Font.system(size: 26, weight: .semibold, design: .serif)
    static let serifBody = Font.system(size: 17, weight: .regular, design: .serif)
    static let serifCaption = Font.system(size: 13, weight: .regular, design: .serif)
}

// MARK: - 主题感知颜色 View Modifier

extension View {
    func themedForeground(_ role: ThemeColorRole) -> some View {
        modifier(ThemedForeground(role: role))
    }

    func themedBackground(_ role: ThemeColorRole) -> some View {
        modifier(ThemedBackground(role: role))
    }
}

enum ThemeColorRole {
    case background, surface, surfaceElevated
    case textPrimary, textSecondary, textTertiary
    case accent, accentSoft
    case success, warning, error
    case borderSubtle, borderMedium, borderStrong
    case selectionBackground
}

private struct ThemedForeground: ViewModifier {
    @Environment(\.themePalette) private var palette
    let role: ThemeColorRole

    func body(content: Content) -> some View {
        content.foregroundStyle(color)
    }

    private var color: Color {
        switch role {
        case .background: return palette.background
        case .surface: return palette.surface
        case .surfaceElevated: return palette.surfaceElevated
        case .textPrimary: return palette.textPrimary
        case .textSecondary: return palette.textSecondary
        case .textTertiary: return palette.textTertiary
        case .accent: return palette.accent
        case .accentSoft: return palette.accentSoft
        case .success: return palette.success
        case .warning: return palette.warning
        case .error: return palette.error
        case .borderSubtle: return palette.borderSubtle
        case .borderMedium: return palette.borderMedium
        case .borderStrong: return palette.borderStrong
        case .selectionBackground: return palette.selectionBackground
        }
    }
}

private struct ThemedBackground: ViewModifier {
    @Environment(\.themePalette) private var palette
    let role: ThemeColorRole

    func body(content: Content) -> some View {
        content.background(color)
    }

    private var color: Color {
        switch role {
        case .background: return palette.background
        case .surface: return palette.surface
        case .surfaceElevated: return palette.surfaceElevated
        case .textPrimary: return palette.textPrimary
        case .textSecondary: return palette.textSecondary
        case .textTertiary: return palette.textTertiary
        case .accent: return palette.accent
        case .accentSoft: return palette.accentSoft
        case .success: return palette.success
        case .warning: return palette.warning
        case .error: return palette.error
        case .borderSubtle: return palette.borderSubtle
        case .borderMedium: return palette.borderMedium
        case .borderStrong: return palette.borderStrong
        case .selectionBackground: return palette.selectionBackground
        }
    }
}

// MARK: - 专业玻璃面板修饰符（主题感知版 + V2 升级）

struct PremiumGlassPanel: ViewModifier {
    @Environment(\.themePalette) private var palette
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.lg
    var elevation: Elevation = .md
    var isHighlighted: Bool = false
    var isPressed: Bool = false

    enum Elevation {
        case sm, md, lg, xl

        var shadow: Shadow {
            switch self {
            case .sm: return DesignSystem.Shadows.sm
            case .md: return DesignSystem.Shadows.md
            case .lg: return DesignSystem.Shadows.lg
            case .xl: return DesignSystem.Shadows.xl
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHighlighted ? palette.selectionBackground.opacity(0.46) : palette.surfaceElevated.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isHighlighted ? palette.accent.opacity(0.42) : palette.borderSubtle, lineWidth: 0.8)
            )
            .animation(DesignSystem.Animation.fast, value: isHighlighted)
            .animation(DesignSystem.Animation.fast, value: isPressed)
    }
}

// MARK: - 高级按钮样式（主题感知）

struct PremiumButtonStyle: ButtonStyle {
    @Environment(\.themePalette) private var palette
    var style: Style = .primary
    var size: Size = .md

    @Environment(\.isEnabled) private var isEnabled

    enum Style {
        case primary, secondary, ghost, destructive, accent
    }

    enum Size {
        case sm, md, lg
    }

    private var height: CGFloat {
        switch size {
        case .sm: return 28
        case .md: return 36
        case .lg: return 44
        }
    }

    private func backgroundColor(isPressed: Bool, isEnabled: Bool) -> Color {
        guard isEnabled else { return palette.surface.opacity(0.5) }

        switch style {
        case .primary:
            return isPressed
                ? palette.surfaceElevated.opacity(0.9)
                : palette.surfaceElevated
        case .accent:
            return isPressed
                ? palette.accent.opacity(0.85)
                : palette.accent
        case .secondary:
            return isPressed
                ? palette.surface.opacity(0.9)
                : palette.surface
        case .ghost:
            return isPressed
                ? palette.borderSubtle
                : Color.clear
        case .destructive:
            return isPressed
                ? palette.error.opacity(0.85)
                : palette.error
        }
    }

    private func foregroundColor(isEnabled: Bool) -> Color {
        guard isEnabled else { return palette.textTertiary }

        switch style {
        case .primary, .secondary, .ghost:
            return palette.textPrimary
        case .accent, .destructive:
            return Color.white
        }
    }

    private func borderColor(isPressed: Bool, isEnabled: Bool) -> Color {
        guard isEnabled else { return palette.borderSubtle.opacity(0.5) }

        switch style {
        case .primary, .accent, .destructive:
            return .clear
        case .secondary:
            return isPressed
                ? palette.borderStrong.opacity(0.8)
                : palette.borderMedium
        case .ghost:
            return isPressed
                ? palette.borderSubtle.opacity(0.6)
                : .clear
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyStrong)
            .foregroundStyle(foregroundColor(isEnabled: isEnabled))
            .padding(.horizontal, size == .sm ? 12 : size == .lg ? 20 : 16)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed, isEnabled: isEnabled))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                    .stroke(borderColor(isPressed: configuration.isPressed, isEnabled: isEnabled), lineWidth: 1)
            )
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - 扁平操作按钮（主题感知）

struct FlatActionButtonStyle: ButtonStyle {
    @Environment(\.themePalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    var style: Style = .secondary
    var height: CGFloat = 34

    enum Style {
        case secondary, accent, destructive
    }

    private func fillColor(isPressed: Bool) -> Color {
        guard isEnabled else { return palette.surfaceElevated.opacity(0.38) }

        switch style {
        case .secondary:
            return palette.surfaceElevated.opacity(isPressed ? 0.58 : 0.72)
        case .accent:
            return palette.accent.opacity(isPressed ? 0.78 : 0.9)
        case .destructive:
            return palette.error.opacity(isPressed ? 0.72 : 0.82)
        }
    }

    private var foregroundColor: Color {
        guard isEnabled else { return palette.textTertiary }
        return style == .secondary ? palette.textPrimary : Color.white
    }

    private var borderColor: Color {
        guard isEnabled else { return palette.borderSubtle.opacity(0.45) }

        switch style {
        case .secondary:
            return palette.borderSubtle
        case .accent:
            return palette.accent.opacity(0.55)
        case .destructive:
            return palette.error.opacity(0.55)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
            .animation(DesignSystem.Animation.fast, value: isEnabled)
    }
}

// MARK: - 专业卡片修饰符

struct PremiumCard: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.lg
    var isHoverable: Bool = true

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .modifier(PremiumGlassPanel(
                cornerRadius: cornerRadius,
                elevation: .sm,
                isHighlighted: isHovering
            ))
            .animation(DesignSystem.Animation.default, value: isHovering)
            .onHover { hovering in
                if isHoverable {
                    isHovering = hovering
                }
            }
    }
}

// MARK: - 主题感知背景

struct PremiumBackground: View {
    @Environment(\.themePalette) private var palette

    var body: some View {
        ZStack {
            palette.background

            LinearGradient(
                colors: [
                    palette.heroGradient.first ?? palette.surface,
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.6)

            // 微妙的 mesh 渐变装饰点
            RadialGradient(
                colors: [palette.accent.opacity(0.06), Color.clear],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 500
            )

            RadialGradient(
                colors: [palette.accent.opacity(0.04), Color.clear],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Mesh Gradient Logo 背景

struct MeshGradientBackground: View {
    let colors: [Color]
    var animated: Bool = false
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: animated ? 1.0/30.0 : 0)) { timeline in
            Canvas { ctx, size in
                let t = animated ? CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12)) / 12 : phase

                for (i, color) in colors.enumerated() {
                    let angle = Double(i) / Double(colors.count) * .pi * 2 + Double(t) * .pi * 0.3
                    let cx = size.width * 0.5 + CGFloat(cos(angle)) * size.width * 0.3
                    let cy = size.height * 0.5 + CGFloat(sin(angle)) * size.height * 0.3

                    let gradient = Gradient(stops: [
                        .init(color: color.opacity(0.9), location: 0),
                        .init(color: color.opacity(0), location: 1)
                    ])

                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: cx - size.width * 0.55,
                            y: cy - size.height * 0.55,
                            width: size.width * 1.1,
                            height: size.height * 1.1
                        )),
                        with: .radialGradient(
                            gradient,
                            center: CGPoint(x: cx, y: cy),
                            startRadius: 0,
                            endRadius: size.width * 0.55
                        )
                    )
                }
            }
        }
    }
}

// MARK: - 视觉效果模糊

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - 分隔线

struct PremiumDivider: View {
    @Environment(\.themePalette) private var palette
    var horizontalPadding: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(palette.borderSubtle)
            .frame(height: 1)
            .padding(.horizontal, horizontalPadding)
    }
}

// MARK: - View 扩展

extension View {
    func premiumGlassPanel(
        cornerRadius: CGFloat = DesignSystem.CornerRadius.lg,
        elevation: PremiumGlassPanel.Elevation = .md,
        isHighlighted: Bool = false,
        isPressed: Bool = false
    ) -> some View {
        modifier(PremiumGlassPanel(
            cornerRadius: cornerRadius,
            elevation: elevation,
            isHighlighted: isHighlighted,
            isPressed: isPressed
        ))
    }

    func premiumCard(
        cornerRadius: CGFloat = DesignSystem.CornerRadius.lg,
        isHoverable: Bool = true
    ) -> some View {
        modifier(PremiumCard(cornerRadius: cornerRadius, isHoverable: isHoverable))
    }

    func premiumButtonStyle(
        _ style: PremiumButtonStyle.Style = .primary,
        size: PremiumButtonStyle.Size = .md
    ) -> some View {
        buttonStyle(PremiumButtonStyle(style: style, size: size))
    }

    func flatActionButton(
        _ style: FlatActionButtonStyle.Style = .secondary,
        height: CGFloat = 34
    ) -> some View {
        buttonStyle(FlatActionButtonStyle(style: style, height: height))
    }
}

// MARK: - 兼容旧 API（保留 .textPrimary/.textSecondary/.textTertiary）
//
// 旧 View 大量使用 `.textPrimary()` / `.textSecondary()`，
// 这里把旧方法绑定到默认 midnight 调色板，避免大范围破坏。
// 后续可在每个 View 改用 `@Environment(\.themePalette)` 获取真实主题色。

// MARK: - 兼容旧 API（保留 .textPrimary/.textSecondary/.textTertiary）
//
// 旧 View 大量使用 `.textPrimary()` / `.textSecondary()`，
// 这里把旧方法绑定到当前主题调色板（通过 Environment），避免大范围破坏。
// 后续可在每个 View 改用 `.themedForeground(.textPrimary)` 等显式 API。

extension View {
    func textPrimary() -> some View { modifier(ThemedForegroundCompat(role: .textPrimary)) }
    func textSecondary() -> some View { modifier(ThemedForegroundCompat(role: .textSecondary)) }
    func textTertiary() -> some View { modifier(ThemedForegroundCompat(role: .textTertiary)) }
}

/// 主题感知的旧 API 兼容 modifier。
/// 与 `ThemedForeground` 行为一致，独立命名以避免与 `@available` 标记混淆。
struct ThemedForegroundCompat: ViewModifier {
    @Environment(\.themePalette) private var palette
    let role: ThemeColorRole

    func body(content: Content) -> some View {
        content.foregroundStyle(resolve(palette))
    }

    private func resolve(_ p: ThemePalette) -> Color {
        switch role {
        case .textPrimary: return p.textPrimary
        case .textSecondary: return p.textSecondary
        case .textTertiary: return p.textTertiary
        default: return p.textPrimary
        }
    }
}
