import SwiftUI

// MARK: - 专业设计系统 - 黑灰色系
struct DesignSystem {
    // MARK: - 颜色系统 - 纯黑灰
    struct Colors {
        static let background = Color(red: 0.08, green: 0.08, blue: 0.08)
        static let surface = Color(red: 0.12, green: 0.12, blue: 0.12)
        static let surfaceElevated = Color(red: 0.16, green: 0.16, blue: 0.16)
        
        static let primary = Color(red: 0.85, green: 0.85, blue: 0.85)
        static let primarySoft = Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.12)
        
        static let accent = Color(red: 0.92, green: 0.92, blue: 0.92)
        static let accentSoft = Color(red: 0.92, green: 0.92, blue: 0.92).opacity(0.10)
        
        static let success = Color(red: 0.85, green: 0.85, blue: 0.85)
        static let warning = Color(red: 0.85, green: 0.85, blue: 0.85)
        static let error = Color(red: 0.85, green: 0.85, blue: 0.85)
        
        static let textPrimary = Color.white.opacity(0.90)
        static let textSecondary = Color.white.opacity(0.55)
        static let textTertiary = Color.white.opacity(0.35)
        
        static let borderSubtle = Color.white.opacity(0.06)
        static let borderMedium = Color.white.opacity(0.10)
        static let borderStrong = Color.white.opacity(0.15)
        
        static let overlay = Color.black.opacity(0.35)
    }
    
    // MARK: - 间距系统
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
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    // MARK: - 阴影系统 - 干净克制
    struct Shadows {
        static let sm = Shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        static let md = Shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        static let lg = Shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
        static let xl = Shadow(color: .black.opacity(0.20), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - 动画系统
    struct Animation {
        static let fast = SwiftUI.Animation.spring(response: 0.20, dampingFraction: 0.88)
        static let `default` = SwiftUI.Animation.spring(response: 0.30, dampingFraction: 0.85)
        static let slow = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.82)
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - 字体系统
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
}

// MARK: - 专业玻璃面板修饰符 - 干净克制
struct PremiumGlassPanel: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.lg
    var elevation: Elevation = .md
    var isHighlighted: Bool = false
    var isPressed: Bool = false
    
    enum Elevation {
        case sm, md, lg, xl
    }
    
    private var shadow: Shadow {
        switch elevation {
        case .sm: return DesignSystem.Shadows.sm
        case .md: return DesignSystem.Shadows.md
        case .lg: return DesignSystem.Shadows.lg
        case .xl: return DesignSystem.Shadows.xl
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 主背景 - 简洁
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(DesignSystem.Colors.surfaceElevated.opacity(0.92))
                    
                    // 边框 - 克制
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            isHighlighted 
                                ? DesignSystem.Colors.primary.opacity(0.35)
                                : DesignSystem.Colors.borderSubtle,
                            lineWidth: isHighlighted ? 1.2 : 0.8
                        )
                }
            )
            // 阴影 - 干净克制
            .shadow(
                color: shadow.color,
                radius: shadow.radius * (isPressed ? 0.6 : 1),
                x: shadow.x,
                y: shadow.y * (isPressed ? 0.6 : 1)
            )
            .scaleEffect(isPressed ? 0.995 : 1)
            .animation(DesignSystem.Animation.fast, value: isHighlighted)
            .animation(DesignSystem.Animation.fast, value: isPressed)
    }
}

// MARK: - 高级按钮样式
struct PremiumButtonStyle: ButtonStyle {
    var style: Style = .primary
    var size: Size = .md

    @Environment(\.isEnabled) private var isEnabled
    
    enum Style {
        case primary, secondary, ghost, destructive
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
        guard isEnabled else { return DesignSystem.Colors.surface.opacity(0.5) }
        
        switch style {
        case .primary:
            return isPressed 
                ? DesignSystem.Colors.surfaceElevated.opacity(0.9)
                : DesignSystem.Colors.surfaceElevated
        case .secondary:
            return isPressed
                ? DesignSystem.Colors.surface.opacity(0.9)
                : DesignSystem.Colors.surface
        case .ghost:
            return isPressed
                ? Color.white.opacity(0.05)
                : Color.clear
        case .destructive:
            return isPressed
                ? DesignSystem.Colors.surfaceElevated.opacity(0.9)
                : DesignSystem.Colors.surfaceElevated
        }
    }
    
    private func foregroundColor(isEnabled: Bool) -> Color {
        guard isEnabled else { return DesignSystem.Colors.textTertiary }
        
        switch style {
        case .primary, .secondary, .destructive, .ghost:
            return DesignSystem.Colors.textPrimary
        }
    }
    
    private func borderColor(isPressed: Bool, isEnabled: Bool) -> Color {
        guard isEnabled else { return DesignSystem.Colors.borderSubtle.opacity(0.5) }
        
        switch style {
        case .primary, .destructive:
            return .clear
        case .secondary:
            return isPressed 
                ? DesignSystem.Colors.borderStrong.opacity(0.8)
                : DesignSystem.Colors.borderMedium
        case .ghost:
            return isPressed
                ? DesignSystem.Colors.borderSubtle.opacity(0.6)
                : .clear
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyStrong)
            .foregroundColor(foregroundColor(isEnabled: isEnabled))
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
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
                elevation: isHovering ? .lg : .md,
                isHighlighted: isHovering
            ))
            .scaleEffect(isHovering ? 1.01 : 1)
            .animation(DesignSystem.Animation.default, value: isHovering)
            .onHover { hovering in
                if isHoverable {
                    isHovering = hovering
                }
            }
    }
}

// MARK: - 专业背景 - 干净简洁
struct PremiumBackground: View {
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
            
            // 微妙的顶部渐变
            LinearGradient(
                colors: [
                    DesignSystem.Colors.surface.opacity(0.6),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
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
    var horizontalPadding: CGFloat = 0
    
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.borderSubtle)
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
    
    func textPrimary() -> some View {
        foregroundColor(DesignSystem.Colors.textPrimary)
    }
    
    func textSecondary() -> some View {
        foregroundColor(DesignSystem.Colors.textSecondary)
    }
    
    func textTertiary() -> some View {
        foregroundColor(DesignSystem.Colors.textTertiary)
    }
}
