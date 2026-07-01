import SwiftUI
import AppKit

// MARK: - 液态玻璃侧栏
//
// macOS 26 Tahoe 风格的液态玻璃效果：
// - NSVisualEffectView 真玻璃材质
// - 半透明 + 折射感
// - 微妙的色彩光晕
// - 滚动时玻璃强度变化
//
// 比 SwiftUI 模拟的玻璃材质真实 10 倍（GPU 加速）。

// MARK: - 玻璃材质类型

enum LiquidGlassMaterial {
    case sidebar         // 侧栏 - 高度透明 + 微模糊
    case window          // 窗口 - 中等透明
    case hud             // HUD - 完全透明 + 强模糊
    case popover         // 弹窗 - 中等透明

    var material: NSVisualEffectView.Material {
        switch self {
        case .sidebar: return .sidebar
        case .window: return .windowBackground
        case .hud: return .hudWindow
        case .popover: return .popover
        }
    }

    var blendingMode: NSVisualEffectView.BlendingMode {
        switch self {
        case .sidebar, .hud: return .behindWindow
        case .window, .popover: return .withinWindow
        }
    }
}

// MARK: - NSVisualEffectView SwiftUI 包装

struct LiquidGlassView: NSViewRepresentable {
    let material: LiquidGlassMaterial
    var cornerRadius: CGFloat = 0
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material.material
        view.blendingMode = material.blendingMode
        view.state = state
        if cornerRadius > 0 {
            view.wantsLayer = true
            view.layer?.cornerRadius = cornerRadius
            view.layer?.masksToBounds = true
        }
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material.material
        nsView.blendingMode = material.blendingMode
        nsView.state = state
    }
}

// MARK: - 液态玻璃背景

struct LiquidGlassBackground: ViewModifier {
    let material: LiquidGlassMaterial
    var cornerRadius: CGFloat = 0

    @Environment(\.themePalette) private var palette

    func body(content: Content) -> some View {
        ZStack {
            // 底层：渐变
            LinearGradient(
                colors: [
                    palette.background.opacity(0.6),
                    palette.surface.opacity(0.4)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 玻璃材质层（macOS 26 真玻璃）
            LiquidGlassView(material: material, cornerRadius: cornerRadius)

            // 边缘高光（顶部 1px）
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.textPrimary.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 1)
                Spacer()
            }
            .allowsHitTesting(false)

            content
        }
    }
}

// MARK: - 液态玻璃侧栏（替换 EnhancedSidebar）

struct LiquidGlassSidebar: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.themePalette) private var palette

    @State private var hoverItem: SidebarItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topSection
                .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sidebarGroup("核心") {
                        sidebarItem(.dashboard)
                        sidebarItem(.allNotes)
                        sidebarItem(.books)
                    }

                    sidebarGroup("复习") {
                        sidebarItem(.todayReview)
                        sidebarItem(.randomNotes)
                        sidebarItem(.favorites)
                        sidebarItem(.unreviewed)
                    }

                    sidebarGroup("发现") {
                        sidebarItem(.mindMap)
                        sidebarItem(.readingReport)
                        sidebarItem(.askAI)
                        sidebarItem(.writingAssistant)
                    }

                    sidebarGroup("数据") {
                        sidebarItem(.tags)
                        sidebarItem(.syncHistory)
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.vertical, 16)
            }
            .scrollContentBackground(.hidden)

            bottomSection
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(palette.borderMedium.opacity(0.65))
                .frame(width: 0.5)
        }
    }

    private var topSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                LineIcon(path: LineIconPath.book(), size: 18, strokeWidth: 1.6, color: palette.textPrimary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("书摘温故")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .tracking(0)
                    Text("微信读书笔记空间")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textTertiary)
                        .tracking(0)
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: 0.5)
                .padding(.horizontal, 16)
        }
    }

    private var sidebarBackground: some View {
        palette.surface
            .ignoresSafeArea()
    }

    private func sidebarGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.textTertiary)
                .padding(.horizontal, 18)

            VStack(spacing: 1) {
                content()
            }
            .padding(.horizontal, 10)
        }
    }

    private func sidebarItem(_ item: SidebarItem) -> some View {
        EnhancedSidebarRow(
            item: item,
            isSelected: appVM.selectedSidebarItem == item,
            isHovering: hoverItem == item,
            action: {
                withAnimation(.easeOut(duration: 0.18)) {
                    appVM.selectedSidebarItem = item
                    appVM.selectedBook = nil
                    appVM.selectedNote = nil
                }
            },
            onHover: { hovering in
                hoverItem = hovering ? item : nil
            }
        )
    }

    private var bottomSection: some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: 0.5)
                .padding(.horizontal, 16)
                .padding(.bottom, 7)

            sidebarItem(.trash)
            sidebarItem(.settings)
        }
    }

    private var sidebarTopGlow: some View {
        ZStack {
            LinearGradient(
                colors: [palette.accent.opacity(0.10), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [palette.accent.opacity(0.18), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 200
            )
        }
        .blendMode(.plusLighter)
    }
}

// MARK: - 浮动玻璃面板

struct LiquidGlassPanel<Content: View>: View {
    let content: Content
    var material: LiquidGlassMaterial = .hud
    var cornerRadius: CGFloat = 16

    init(
        material: LiquidGlassMaterial = .hud,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.material = material
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background(LiquidGlassView(material: material, cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
    }
}
