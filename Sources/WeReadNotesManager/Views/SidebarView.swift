import SwiftUI

struct SidebarView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            // App Logo & Title
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.4),
                                    DesignSystem.Colors.accent.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("书摘温故")
                        .font(.title3)
                        .textPrimary()
                    Text("阅读笔记工作空间")
                        .font(.caption)
                        .textSecondary()
                }
            }
            .padding(.top, DesignSystem.Spacing.xxxl)
            .padding(.horizontal, DesignSystem.Spacing.md)

            // Navigation Groups - 精简版
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    sidebarGroup("核心") {
                        sidebarItem(.dashboard)
                        sidebarItem(.books)
                        sidebarItem(.allNotes)
                    }

                    sidebarGroup("复习") {
                        sidebarItem(.todayReview)
                        sidebarItem(.favorites)
                    }

                    sidebarGroup("发现") {
                        sidebarItem(.themeMap)
                        sidebarItem(.askAI)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }

            Spacer()

            // Bottom Items
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                sidebarItem(.trash)
                sidebarItem(.settings)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignSystem.Colors.surface)
    }

    private func sidebarGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title.uppercased())
                .font(.smallStrong)
                .textTertiary()
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xxs)
            content()
        }
    }

    private func sidebarItem(_ item: SidebarItem) -> some View {
        SidebarRow(
            item: item,
            isSelected: appVM.selectedSidebarItem == item
        ) {
            appVM.selectedSidebarItem = item
            appVM.selectedBook = nil
            appVM.selectedNote = nil
        }
    }
}

private struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon with background
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs, style: .continuous)
                        .fill(
                            isSelected
                                ? DesignSystem.Colors.primary.opacity(0.25)
                                : DesignSystem.Colors.surfaceElevated.opacity(isHovering ? 0.8 : 0)
                        )
                    
                    Image(systemName: item.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            isSelected
                                ? DesignSystem.Colors.primary
                                : (isHovering ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                        )
                }
                .frame(width: 28, height: 28)
                
                // Label
                Text(item.label)
                    .font(.bodyStrong)
                    .foregroundStyle(
                        isSelected
                            ? DesignSystem.Colors.textPrimary
                            : (isHovering ? DesignSystem.Colors.textPrimary.opacity(0.9) : DesignSystem.Colors.textSecondary)
                    )
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 3, height: 16)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                    .fill(
                        isSelected
                            ? DesignSystem.Colors.primarySoft
                            : (isHovering ? DesignSystem.Colors.surfaceElevated.opacity(0.7) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(DesignSystem.Animation.fast, value: isSelected)
        .animation(DesignSystem.Animation.fast, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
