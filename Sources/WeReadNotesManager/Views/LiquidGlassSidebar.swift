import SwiftUI
import AppKit

// MARK: - 扁平纸面侧栏

// MARK: - 纸面侧栏

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
                        sidebarItem(.writingCards)
                        sidebarItem(.shareCardStudio)
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
            HStack(spacing: 12) {
                SidebarBrandLogo()
                    .padding(5)
                    .frame(width: 54, height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.clear)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.accent.opacity(0.45), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("树懒书摘")
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
            .padding(.vertical, 4)
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

}

private struct SidebarBrandLogo: View {
    private var image: NSImage? {
        guard let url = Bundle.module.url(forResource: "SidebarLogo", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(ThemePalette.brandBlue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 侧栏行（从旧 EnhancedSidebar 迁移，保留复用）

struct EnhancedSidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovering: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void

    @Environment(\.themePalette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(isSelected ? palette.accent : Color.clear)
                    .frame(width: 3, height: 18)

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
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isSelected ? palette.accent.opacity(0.28) : Color.clear,
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
            return palette.accentSoft
        } else if isHovering {
            return palette.accent.opacity(0.08)
        }
        return .clear
    }

    private var iconColor: Color {
        if isSelected {
            return palette.accent
        } else if isHovering {
            return palette.accent.opacity(0.88)
        }
        return palette.textTertiary
    }

    private var textColor: Color {
        if isSelected {
            return palette.textPrimary
        } else if isHovering {
            return palette.textPrimary.opacity(0.92)
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
        case .topicClusters: return LineIcon(path: LineIconPath.stack(), size: 16)
        case .knowledgeGraph: return LineIcon(path: LineIconPath.brain(), size: 16)
        case .writingCards: return LineIcon(path: LineIconPath.stack(), size: 16)
        case .askAI: return LineIcon(path: LineIconPath.sparkle(), size: 16)
        case .writingAssistant: return LineIcon(path: LineIconPath.sparkleFour(), size: 16)
        case .shareCardStudio: return LineIcon(path: LineIconPath.chart(), size: 16)
        case .trash: return LineIcon(path: LineIconPath.trash(), size: 16)
        case .syncHistory: return LineIcon(path: LineIconPath.refresh(), size: 16)
        case .settings: return LineIcon(path: LineIconPath.gear(), size: 16)
        }
    }
}
