import SwiftUI

// MARK: - 升级版侧栏
//
// 设计参考 Linear / Things 3 / Raycast：
// - 顶部装饰光带
// - Logo 区有 3D 立体感
// - 每个分组有微妙分隔
// - 选中项有左侧 2px 强调色"书签"
// - 全部用线性图标

struct EnhancedSidebar: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.themePalette) private var palette

    @State private var hoverItem: SidebarItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部装饰
            topSection
                .padding(.top, 18)

            // 导航
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
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

                    Spacer().frame(height: 100)
                }
                .padding(.vertical, 18)
            }

            // 底部
            bottomSection
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 渐变背景（侧栏专属）
        .background(sidebarBackground)
        // 顶部装饰光带
        .overlay(alignment: .top) {
            sidebarTopGlow
                .frame(height: 120)
                .allowsHitTesting(false)
        }
        // 右侧分隔线
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, palette.borderMedium.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 0.5)
                .padding(.vertical, 20)
                .allowsHitTesting(false)
        }
    }

    // MARK: - 顶部 Logo

    private var topSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Logo
            HStack(spacing: 12) {
                BrandLogo(size: 36, color: palette.accent)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(palette.accentSoft)
                    )
                    .overlay(
                        Circle()
                            .stroke(palette.accent.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: palette.accent.opacity(0.3), radius: 12, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("书摘温故")
                        .font(Typography.title1)
                        .foregroundStyle(palette.textPrimary)
                        .tracking(-0.4)
                    Text("阅读 · 笔记 · 思考")
                        .font(Typography.micro)
                        .foregroundStyle(palette.textTertiary)
                        .tracking(0.8)
                        .textCase(.uppercase)
                }
            }
            .padding(.horizontal, 16)

            // 装饰分隔线
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, palette.borderMedium, Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
                .padding(.horizontal, 14)
                .padding(.top, 14)
        }
    }

    // MARK: - 导航分组

    private func sidebarGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                MicroLabel(text: title, color: palette.textTertiary)
                Rectangle()
                    .fill(palette.borderSubtle)
                    .frame(height: 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            VStack(spacing: 2) {
                content()
            }
            .padding(.horizontal, 8)
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

    // MARK: - 底部

    private var bottomSection: some View {
        VStack(spacing: 4) {
            // 分隔线
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, palette.borderMedium, Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            sidebarItem(.trash)
            sidebarItem(.settings)
        }
    }

    // MARK: - 背景

    private var sidebarBackground: some View {
        ZStack {
            palette.surface

            // Paper 主题用更亮的背景
            if palette.accent == ThemePalette.paper.accent {
                Color(red: 0.93, green: 0.87, blue: 0.74)
            }

            // 微妙渐变
            LinearGradient(
                colors: [
                    palette.surfaceElevated.opacity(0.4),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    private var sidebarTopGlow: some View {
        ZStack {
            // 主光带
            LinearGradient(
                colors: [palette.accent.opacity(0.10), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )

            // 角落光晕
            RadialGradient(
                colors: [palette.accent.opacity(0.15), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 200
            )
        }
        .blendMode(.plusLighter)
    }
}

// MARK: - 侧栏行

struct EnhancedSidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovering: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void

    @Environment(\.themePalette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    iconForItem(item)
                        .foregroundStyle(iconColor)
                        .frame(width: 16, height: 16)
                }
                .frame(width: 24, height: 24, alignment: .center)

                Text(item.label)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(textColor)
                    .tracking(0)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isSelected ? palette.borderMedium : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { onHover($0) }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }

    private var backgroundFill: Color {
        if isSelected {
            return palette.textPrimary.opacity(0.075)
        } else if isHovering {
            return palette.textPrimary.opacity(0.045)
        }
        return .clear
    }

    private var iconColor: Color {
        if isSelected {
            return palette.textPrimary
        } else if isHovering {
            return palette.textSecondary
        }
        return palette.textTertiary
    }

    private var textColor: Color {
        if isSelected {
            return palette.textPrimary
        } else if isHovering {
            return palette.textPrimary.opacity(0.9)
        }
        return palette.textSecondary
    }

    private func iconForItem(_ item: SidebarItem) -> LineIcon {
        switch item {
        case .dashboard: return LineIcon(path: LineIconPath.home(), size: 16)
        case .allNotes: return LineIcon(path: LineIconPath.search(), size: 16)
        case .todayReview: return LineIcon(path: LineIconPath.stack(), size: 16)
        case .randomNotes: return LineIcon(path: LineIconPath.sparkleFour(), size: 16)
        case .mindMap: return LineIcon(path: LineIconPath.brain(), size: 16)
        case .readingReport: return LineIcon(path: LineIconPath.chart(), size: 16)
        case .favorites: return LineIcon(path: LineIconPath.heart(), size: 16)
        case .unreviewed: return LineIcon(path: LineIconPath.bookmark(), size: 16)
        case .books: return LineIcon(path: LineIconPath.library(), size: 16)
        case .tags: return LineIcon(path: LineIconPath.tag(), size: 16)
        case .askAI: return LineIcon(path: LineIconPath.sparkle(), size: 16)
        case .writingAssistant: return LineIcon(path: LineIconPath.sparkleFour(), size: 16)
        case .trash: return LineIcon(path: LineIconPath.trash(), size: 16)
        case .syncHistory: return LineIcon(path: LineIconPath.refresh(), size: 16)
        case .settings: return LineIcon(path: LineIconPath.gear(), size: 16)
        }
    }
}
