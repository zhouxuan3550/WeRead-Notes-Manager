import SwiftUI

struct HoverLift: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
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
                icon: "arrow.triangle.2.circlepath",
                title: "同步微信读书",
                isActive: false,
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
    @Environment(\.themePalette) private var palette
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isActive ? palette.accent : palette.textSecondary)
                .rotationEffect(.degrees(isBusy ? 360 : 0))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs, style: .continuous)
                        .fill(isActive 
                            ? palette.accentSoft.opacity(0.92)
                            : palette.surfaceElevated.opacity(isHovering ? 1.0 : 0.92)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs, style: .continuous)
                        .stroke(isActive 
                            ? palette.accent.opacity(0.46)
                            : palette.borderSubtle,
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
        .help(title)
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
    @Environment(\.themePalette) private var palette
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isFocused ? palette.accent : palette.textSecondary)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("搜索书名、作者、内容")
                        .font(.body)
                        .foregroundStyle(palette.textTertiary.opacity(0.86))
                        .allowsHitTesting(false)
                }

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(palette.textPrimary)
                    .focused($isFocused)
                    .onSubmit(onCommit)
            }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .fill(isFocused 
                    ? palette.surfaceElevated.opacity(0.96)
                    : palette.surfaceElevated.opacity(0.76)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .stroke(isFocused 
                    ? palette.accent.opacity(0.46)
                    : palette.borderSubtle,
                    lineWidth: 0.8
                )
        )
        .animation(DesignSystem.Animation.fast, value: isFocused)
    }
}
