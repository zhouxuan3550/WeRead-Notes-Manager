import SwiftUI

struct HoverLift: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? 1.018 : 1)
            .shadow(color: Color.black.opacity(isHovering ? 0.16 : 0.08), radius: isHovering ? 14 : 8, x: 0, y: isHovering ? 8 : 4)
            .animation(DesignSystem.Animation.default, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    func hoverLift() -> some View {
        modifier(HoverLift())
    }
}

struct CommandBar: View {
    @Binding var searchText: String
    let isAutoSyncEnabled: Bool
    let isSyncing: Bool
    let onImport: () -> Void
    let onExport: () -> Void
    let onSync: () -> Void
    let onSearch: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            CommandIconButton(
                icon: "square.and.arrow.down",
                title: "导入",
                action: onImport
            )
            .keyboardShortcut("i", modifiers: .command)

            CommandIconButton(
                icon: "square.and.arrow.up",
                title: "导出",
                action: onExport
            )
            .keyboardShortcut("e", modifiers: .command)

            CommandIconButton(
                icon: isAutoSyncEnabled ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle",
                title: isAutoSyncEnabled ? "立即同步" : "开启同步",
                isActive: isAutoSyncEnabled,
                isBusy: isSyncing,
                action: onSync
            )
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(isSyncing)

            SearchField(text: $searchText, onCommit: onSearch)
        }
        .padding(DesignSystem.Spacing.sm)
        .premiumGlassPanel(cornerRadius: DesignSystem.CornerRadius.md, elevation: .sm)
    }
}

private struct CommandIconButton: View {
    let icon: String
    let title: String
    var isActive = false
    var isBusy = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isActive ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                .rotationEffect(.degrees(isBusy ? 360 : 0))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs, style: .continuous)
                        .fill(isActive 
                            ? DesignSystem.Colors.primarySoft 
                            : DesignSystem.Colors.surface.opacity(isHovering ? 0.9 : 0.6)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs, style: .continuous)
                        .stroke(isActive 
                            ? DesignSystem.Colors.primary.opacity(0.4)
                            : DesignSystem.Colors.borderSubtle,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .scaleEffect(isHovering ? 1.06 : 1)
        .animation(DesignSystem.Animation.fast, value: isHovering)
        .animation(isBusy ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: isBusy)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct SearchField: View {
    @Binding var text: String
    let onCommit: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isFocused ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)

            TextField("搜索书名、作者、内容", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .textPrimary()
                .focused($isFocused)
                .onSubmit(onCommit)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .fill(isFocused 
                    ? DesignSystem.Colors.surfaceElevated.opacity(0.95)
                    : DesignSystem.Colors.surface.opacity(0.7)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .stroke(isFocused 
                    ? DesignSystem.Colors.primary.opacity(0.5)
                    : DesignSystem.Colors.borderSubtle,
                    lineWidth: 1
                )
        )
        .animation(DesignSystem.Animation.fast, value: isFocused)
    }
}
