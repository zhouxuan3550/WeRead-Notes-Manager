import SwiftUI

// MARK: - 多主题系统
//
// 设计原则：
// - 每个主题提供完整的语义色 + 字体规范
// - 通过 @Environment 注入到任意 View，避免硬编码颜色
// - 主题切换无需重启，立即生效（@Observable）
// - 字体在 SF Pro 上扩展思源宋体/霞鹜文楷等衬线作为可选
//
// 主题：
//   Midnight 夜墨青（默认）- 深沉克制，带冷色高光
//   Paper    米黄纸张        - 白天阅读，护眼
//   Ink      水墨灰          - 极简派，几乎纯灰
//   Forest   暗夜森林        - 绿色系，沉浸

// MARK: - 主题枚举

enum AppThemeID: String, CaseIterable, Identifiable, Codable {
    case midnight
    case paper
    case ink
    case forest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .midnight: return "夜墨青"
        case .paper: return "米黄纸"
        case .ink: return "水墨灰"
        case .forest: return "暗夜森林"
        }
    }

    var subtitle: String {
        switch self {
        case .midnight: return "深空蓝调，冷静克制"
        case .paper: return "暖纸米色，长文友好"
        case .ink: return "纯灰极简，专注内容"
        case .forest: return "林海墨绿，沉浸阅读"
        }
    }

    var systemImage: String {
        switch self {
        case .midnight: return "moon.stars.fill"
        case .paper: return "doc.richtext.fill"
        case .ink: return "circle.lefthalf.filled"
        case .forest: return "leaf.fill"
        }
    }
}

// MARK: - 主题调色板

struct ThemePalette: Equatable {
    /// 主背景（最底层）
    let background: Color
    /// 次级背景（卡片）
    let surface: Color
    /// 抬升背景（浮起卡片、菜单）
    let surfaceElevated: Color
    /// 主文字
    let textPrimary: Color
    /// 次文字
    let textSecondary: Color
    /// 三级文字（弱化）
    let textTertiary: Color
    /// 主强调色（按钮、链接、关键状态）
    let accent: Color
    /// 强调色柔光背景（chip 背景等）
    let accentSoft: Color
    /// 成功（绿）
    let success: Color
    /// 警告（橙）
    let warning: Color
    /// 错误（红）
    let error: Color
    /// 边框（弱）
    let borderSubtle: Color
    /// 边框（中）
    let borderMedium: Color
    /// 边框（强）
    let borderStrong: Color
    /// 选中态背景
    let selectionBackground: Color
    /// 顶部装饰渐变
    let heroGradient: [Color]
    /// Mesh Gradient 端点（侧栏 Logo 等用）
    let meshColors: [Color]

    // 字体
    let displayFont: Font
    let bodyFont: Font
    let monoFont: Font
    let serifFont: Font

    static let midnight = ThemePalette(
        background: Color(red: 0.06, green: 0.07, blue: 0.10),
        surface: Color(red: 0.10, green: 0.11, blue: 0.14),
        surfaceElevated: Color(red: 0.14, green: 0.16, blue: 0.20),
        textPrimary: Color.white.opacity(0.92),
        textSecondary: Color.white.opacity(0.60),
        textTertiary: Color.white.opacity(0.38),
        accent: Color(red: 0.36, green: 0.55, blue: 0.93), // #5B8DEF
        accentSoft: Color(red: 0.36, green: 0.55, blue: 0.93).opacity(0.14),
        success: Color(red: 0.34, green: 0.78, blue: 0.56),
        warning: Color(red: 0.95, green: 0.68, blue: 0.34),
        error: Color(red: 0.95, green: 0.42, blue: 0.42),
        borderSubtle: Color.white.opacity(0.06),
        borderMedium: Color.white.opacity(0.10),
        borderStrong: Color.white.opacity(0.16),
        selectionBackground: Color(red: 0.36, green: 0.55, blue: 0.93).opacity(0.18),
        heroGradient: [
            Color(red: 0.10, green: 0.16, blue: 0.28),
            Color(red: 0.06, green: 0.07, blue: 0.10)
        ],
        meshColors: [
            Color(red: 0.36, green: 0.55, blue: 0.93),
            Color(red: 0.78, green: 0.45, blue: 0.92),
            Color(red: 0.30, green: 0.78, blue: 0.85)
        ],
        displayFont: .system(size: 34, weight: .bold, design: .default),
        bodyFont: .system(size: 15, weight: .regular, design: .default),
        monoFont: .system(size: 13, weight: .regular, design: .monospaced),
        serifFont: .system(size: 17, weight: .regular, design: .serif)
    )

    static let paper = ThemePalette(
        background: Color(red: 0.96, green: 0.93, blue: 0.86), // #F5EEDC
        surface: Color(red: 0.99, green: 0.97, blue: 0.92),
        surfaceElevated: Color(red: 1.0, green: 0.99, blue: 0.96),
        textPrimary: Color(red: 0.18, green: 0.13, blue: 0.08),
        textSecondary: Color(red: 0.36, green: 0.28, blue: 0.18),
        textTertiary: Color(red: 0.52, green: 0.44, blue: 0.32),
        accent: Color(red: 0.64, green: 0.23, blue: 0.18), // 朱砂
        accentSoft: Color(red: 0.64, green: 0.23, blue: 0.18).opacity(0.12),
        success: Color(red: 0.30, green: 0.55, blue: 0.30),
        warning: Color(red: 0.82, green: 0.50, blue: 0.18),
        error: Color(red: 0.78, green: 0.22, blue: 0.22),
        borderSubtle: Color.black.opacity(0.08),
        borderMedium: Color.black.opacity(0.12),
        borderStrong: Color.black.opacity(0.20),
        selectionBackground: Color(red: 0.64, green: 0.23, blue: 0.18).opacity(0.14),
        heroGradient: [
            Color(red: 0.92, green: 0.85, blue: 0.70),
            Color(red: 0.96, green: 0.93, blue: 0.86)
        ],
        meshColors: [
            Color(red: 0.64, green: 0.23, blue: 0.18),
            Color(red: 0.82, green: 0.50, blue: 0.18),
            Color(red: 0.30, green: 0.45, blue: 0.20)
        ],
        displayFont: .system(size: 34, weight: .bold, design: .serif),
        bodyFont: .system(size: 15, weight: .regular, design: .serif),
        monoFont: .system(size: 13, weight: .regular, design: .monospaced),
        serifFont: .system(size: 17, weight: .regular, design: .serif)
    )

    static let ink = ThemePalette(
        background: Color(red: 0.10, green: 0.10, blue: 0.10),
        surface: Color(red: 0.14, green: 0.14, blue: 0.14),
        surfaceElevated: Color(red: 0.18, green: 0.18, blue: 0.18),
        textPrimary: Color.white.opacity(0.92),
        textSecondary: Color.white.opacity(0.55),
        textTertiary: Color.white.opacity(0.35),
        accent: Color.white.opacity(0.85),
        accentSoft: Color.white.opacity(0.10),
        success: Color(red: 0.70, green: 0.78, blue: 0.70),
        warning: Color(red: 0.85, green: 0.78, blue: 0.60),
        error: Color(red: 0.85, green: 0.62, blue: 0.62),
        borderSubtle: Color.white.opacity(0.06),
        borderMedium: Color.white.opacity(0.10),
        borderStrong: Color.white.opacity(0.16),
        selectionBackground: Color.white.opacity(0.12),
        heroGradient: [
            Color(red: 0.18, green: 0.18, blue: 0.18),
            Color(red: 0.10, green: 0.10, blue: 0.10)
        ],
        meshColors: [
            Color.white.opacity(0.65),
            Color.white.opacity(0.30),
            Color.white.opacity(0.45)
        ],
        displayFont: .system(size: 34, weight: .bold, design: .default),
        bodyFont: .system(size: 15, weight: .regular, design: .default),
        monoFont: .system(size: 13, weight: .regular, design: .monospaced),
        serifFont: .system(size: 17, weight: .regular, design: .serif)
    )

    static let forest = ThemePalette(
        background: Color(red: 0.05, green: 0.10, blue: 0.08),
        surface: Color(red: 0.08, green: 0.14, blue: 0.12),
        surfaceElevated: Color(red: 0.12, green: 0.18, blue: 0.16),
        textPrimary: Color(red: 0.92, green: 0.96, blue: 0.94),
        textSecondary: Color(red: 0.62, green: 0.72, blue: 0.66),
        textTertiary: Color(red: 0.38, green: 0.48, blue: 0.42),
        accent: Color(red: 0.48, green: 0.85, blue: 0.62), // #7AD89E
        accentSoft: Color(red: 0.48, green: 0.85, blue: 0.62).opacity(0.14),
        success: Color(red: 0.56, green: 0.88, blue: 0.66),
        warning: Color(red: 0.95, green: 0.78, blue: 0.40),
        error: Color(red: 0.92, green: 0.46, blue: 0.46),
        borderSubtle: Color.white.opacity(0.06),
        borderMedium: Color.white.opacity(0.10),
        borderStrong: Color.white.opacity(0.16),
        selectionBackground: Color(red: 0.48, green: 0.85, blue: 0.62).opacity(0.16),
        heroGradient: [
            Color(red: 0.10, green: 0.22, blue: 0.18),
            Color(red: 0.05, green: 0.10, blue: 0.08)
        ],
        meshColors: [
            Color(red: 0.48, green: 0.85, blue: 0.62),
            Color(red: 0.20, green: 0.60, blue: 0.50),
            Color(red: 0.78, green: 0.92, blue: 0.42)
        ],
        displayFont: .system(size: 34, weight: .bold, design: .default),
        bodyFont: .system(size: 15, weight: .regular, design: .default),
        monoFont: .system(size: 13, weight: .regular, design: .monospaced),
        serifFont: .system(size: 17, weight: .regular, design: .serif)
    )
}

// MARK: - 主题管理器（@Observable 单例）

@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    var current: AppThemeID {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: "appThemeID")
        }
    }

    var palette: ThemePalette {
        switch current {
        case .midnight: return .midnight
        case .paper: return .paper
        case .ink: return .ink
        case .forest: return .forest
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "appThemeID"),
           let id = AppThemeID(rawValue: raw) {
            self.current = id
        } else {
            self.current = .midnight
        }
    }

    /// 跟随系统的偏好（仅首启动时）
    func applySystemAppearanceIfNeeded() {
        // 简化：用户偏好优先，不跟系统
    }
}

// MARK: - Environment 注入

/// 暴露为 internal 以便 SwiftUI 编译器能在 View 里推断
/// `@Environment(\.themePalette)` 的 keypath 类型。
struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = .midnight
}

extension EnvironmentValues {
    var themePalette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

extension View {
    /// 注入主题调色板。
    func themePalette(_ palette: ThemePalette) -> some View {
        environment(\.themePalette, palette)
    }
}

// MARK: - 主题切换 UI

struct ThemeSwitcher: View {
    @Bindable var store: ThemeStore
    @State private var hoveredTheme: AppThemeID?

    var body: some View {
        @Environment(\.themePalette) var palette
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("主题")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                if let preview = hoveredTheme {
                    ThemePreviewPane(theme: preview)
                        .frame(width: 240, height: 140)
                        .transition(.opacity.combined(with: .scale))
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(AppThemeID.allCases) { theme in
                    ThemeSwatch(
                        theme: theme,
                        isSelected: store.current == theme,
                        action: { store.current = theme },
                        onHover: { hovering in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                hoveredTheme = hovering ? theme : nil
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - 主题预览面板（hover 大图）

struct ThemePreviewPane: View {
    let theme: AppThemeID

    private var p: ThemePalette {
        switch theme {
        case .midnight: return .midnight
        case .paper: return .paper
        case .ink: return .ink
        case .forest: return .forest
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 模拟侧栏 logo
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.clear)
                        .overlay(
                            MeshGradientBackground(colors: p.meshColors, animated: false)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        )
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(p.textPrimary)
                    Text(theme.subtitle)
                        .font(.system(size: 7))
                        .foregroundStyle(p.textSecondary)
                        .lineLimit(1)
                }
            }

            // 模拟卡片
            RoundedRectangle(cornerRadius: 5)
                .fill(p.surfaceElevated)
                .frame(height: 56)
                .overlay(
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 3) {
                            Circle().fill(p.accent).frame(width: 5, height: 5)
                            RoundedRectangle(cornerRadius: 1).fill(p.accent).frame(width: 30, height: 4)
                            Spacer()
                            RoundedRectangle(cornerRadius: 1).fill(p.textSecondary).frame(width: 10, height: 3)
                        }
                        RoundedRectangle(cornerRadius: 1).fill(p.textSecondary).frame(height: 3)
                            .frame(maxWidth: .infinity)
                        RoundedRectangle(cornerRadius: 1).fill(p.textTertiary).frame(height: 3)
                            .frame(maxWidth: 80)
                    }
                    .padding(6),
                    alignment: .topLeading
                )

            // 模拟按钮
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(p.accent)
                    .frame(width: 36, height: 14)
                    .overlay(Text("主按钮").font(.system(size: 7)).foregroundStyle(.white))

                RoundedRectangle(cornerRadius: 3)
                    .stroke(p.borderMedium, lineWidth: 1)
                    .frame(width: 36, height: 14)
                    .overlay(Text("次按钮").font(.system(size: 7)).foregroundStyle(p.textPrimary))
            }

            // 色板
            HStack(spacing: 3) {
                Circle().fill(p.success).frame(width: 8, height: 8)
                Circle().fill(p.warning).frame(width: 8, height: 8)
                Circle().fill(p.error).frame(width: 8, height: 8)
                Circle().fill(p.accent).frame(width: 8, height: 8)
                Spacer()
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(p.background)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(p.borderMedium, lineWidth: 0.5)
        )
    }
}

private struct ThemeSwatch: View {
    @Environment(\.themePalette) var palette
    let theme: AppThemeID
    let isSelected: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void

    private var swatchPalette: ThemePalette {
        switch theme {
        case .midnight: return .midnight
        case .paper: return .paper
        case .ink: return .ink
        case .forest: return .forest
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(Array(swatchPalette.meshColors.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                    }
                    Spacer()
                }
                RoundedRectangle(cornerRadius: 6)
                    .fill(swatchPalette.surface)
                    .frame(height: 32)
                    .overlay(
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(swatchPalette.accent)
                                .frame(width: 16, height: 8)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(swatchPalette.textSecondary)
                                .frame(width: 30, height: 4)
                        }
                        .padding(.horizontal, 6),
                        alignment: .leading
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text(theme.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? palette.accent : palette.borderSubtle,
                            lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(DesignSystem.Animation.fast, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}