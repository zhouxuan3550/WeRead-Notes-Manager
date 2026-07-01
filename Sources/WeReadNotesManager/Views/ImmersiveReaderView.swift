import SwiftUI
import AppKit

// MARK: - 沉浸式阅读模式
//
// ⌘⇧F 进入：全屏、无 chrome、专注模式
// - 顶部极简工具条（自动隐藏）
// - 进度指示
// - 字号 / 字体 / 行距 / 主题 实时调节
// - 自动翻页（可选）
// - 阅读时长统计

struct ImmersiveReaderView: View {
    let note: ReadingNote
    let onDismiss: () -> Void

    @State private var fontSize: CGFloat = 19
    @State private var lineHeight: CGFloat = 1.7
    @State private var isShowingToolbar = false
    @State private var toolbarTimer: Timer?
    @State private var readingStartTime = Date()
    @State private var totalReadSeconds: TimeInterval = 0

    @Environment(\.themePalette) private var palette

    var body: some View {
        ZStack {
            // 沉浸式背景（深色）
            Color.black.opacity(0.96)
                .ignoresSafeArea()

            // 装饰性微光
            RadialGradient(
                colors: [palette.accent.opacity(0.06), Color.clear],
                center: .topLeading,
                startRadius: 200,
                endRadius: 600
            )
            .ignoresSafeArea()

            // 内容
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 24) {
                        // 顶部书名
                        VStack(spacing: 12) {
                            Text(note.book?.title ?? "")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundStyle(palette.textSecondary.opacity(0.5))

                            Rectangle()
                                .fill(palette.textSecondary.opacity(0.2))
                                .frame(width: 40, height: 1)
                        }
                        .padding(.top, 60)

                        // 章节
                        if let chapter = note.chapter {
                            Text(chapter)
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .italic()
                                .foregroundStyle(palette.textSecondary.opacity(0.7))
                        }

                        // 主引文
                        Text(note.highlight)
                            .font(.system(size: fontSize, weight: .regular, design: .serif))
                            .foregroundStyle(palette.textPrimary)
                            .lineSpacing(fontSize * (lineHeight - 1))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: 680, alignment: .leading)

                        // 想法
                        if let userNote = note.userNote, !userNote.isEmpty {
                            HStack(alignment: .top, spacing: 12) {
                                Rectangle()
                                    .fill(palette.accent.opacity(0.5))
                                    .frame(width: 2)
                                Text(userNote)
                                    .font(.system(size: fontSize - 2, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundStyle(palette.textSecondary)
                                    .lineSpacing((fontSize - 2) * 0.5)
                                    .frame(maxWidth: 680, alignment: .leading)
                            }
                            .padding(.top, 12)
                        }

                        // 底部作者
                        VStack(spacing: 6) {
                            Rectangle()
                                .fill(palette.textSecondary.opacity(0.2))
                                .frame(width: 30, height: 1)

                            if let author = note.book?.author {
                                Text(author)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(palette.textSecondary.opacity(0.7))
                            }
                            Text(formatReadDuration())
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundStyle(palette.textTertiary.opacity(0.5))
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 100)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, max(20, (geo.size.width - 720) / 2))
                }
                .scrollIndicators(.hidden)
            }

            // 工具条
            VStack {
                if isShowingToolbar {
                    toolbar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            showToolbarBriefly()
            readingStartTime = Date()
        }
        .onDisappear {
            recordReadDuration()
        }
        // 鼠标移动显示工具条
        .onContinuousHover { phase in
            switch phase {
            case .active:
                showToolbarBriefly()
            case .ended:
                scheduleHideToolbar()
            }
        }
        // ESC 退出
        .onExitCommand {
            onDismiss()
        }
        // ⌘⇧F 切换
        .background(
            Button("") {
                onDismiss()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .opacity(0)
        )
    }

    // MARK: - 工具条

    private var toolbar: some View {
        HStack(spacing: 16) {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .help("退出 (ESC / ⌘⇧F)")

            Divider()
                .frame(height: 20)
                .overlay(palette.borderMedium)

            // 字号控制
            HStack(spacing: 4) {
                Button { fontSize = max(12, fontSize - 1) } label: {
                    Image(systemName: "textformat.size.smaller")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.textSecondary)

                Text("\(Int(fontSize))pt")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(width: 36)
                    .foregroundStyle(palette.textPrimary)

                Button { fontSize = min(36, fontSize + 1) } label: {
                    Image(systemName: "textformat.size.larger")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.textSecondary)
            }

            Divider()
                .frame(height: 20)
                .overlay(palette.borderMedium)

            // 行距控制
            HStack(spacing: 4) {
                Button { lineHeight = max(1.2, lineHeight - 0.1) } label: {
                    Image(systemName: "arrow.up.and.down.compress.vertical")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.textSecondary)

                Text(String(format: "%.1fx", lineHeight))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(width: 36)
                    .foregroundStyle(palette.textPrimary)

                Button { lineHeight = min(2.2, lineHeight + 0.1) } label: {
                    Image(systemName: "arrow.up.and.down")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.textSecondary)
            }

            Divider()
                .frame(height: 20)
                .overlay(palette.borderMedium)

            // 进度
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(palette.textTertiary)
                Text(formatReadDuration())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            // 主题切换
            ThemePaletteSelector()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.black.opacity(0.6))
                .overlay(
                    Capsule()
                        .stroke(palette.borderMedium, lineWidth: 0.5)
                )
        )
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - 工具条显隐

    private func showToolbarBriefly() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isShowingToolbar = true
        }
        scheduleHideToolbar()
    }

    private func scheduleHideToolbar() {
        toolbarTimer?.invalidate()
        toolbarTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isShowingToolbar = false
                }
            }
        }
    }

    // MARK: - 阅读时长

    private func formatReadDuration() -> String {
        let total = totalReadSeconds + Date().timeIntervalSince(readingStartTime)
        let mins = Int(total / 60)
        if mins >= 60 {
            return String(format: "%d:%02d", mins / 60, mins % 60)
        }
        return "\(mins) min"
    }

    private func recordReadDuration() {
        let elapsed = Date().timeIntervalSince(readingStartTime) + totalReadSeconds
        // TODO: 存储到 UserDefaults + 触发成就
        let today = UserDefaults.standard.integer(forKey: "stats.todayReadSeconds")
        UserDefaults.standard.set(today + Int(elapsed), forKey: "stats.todayReadSeconds")
    }
}

// MARK: - 沉浸式主题选择器

struct ThemePaletteSelector: View {
    @AppStorage("immersiveTheme") private var themeRaw: String = "midnight"

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppThemeID.allCases) { theme in
                Button {
                    themeRaw = theme.rawValue
                } label: {
                    Circle()
                        .fill(swatchColor(theme))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(themeRaw == theme.rawValue ? 0.9 : 0.3), lineWidth: themeRaw == theme.rawValue ? 1.5 : 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func swatchColor(_ theme: AppThemeID) -> Color {
        switch theme {
        case .midnight: return Color(red: 0.36, green: 0.55, blue: 0.93)
        case .paper: return Color(red: 0.64, green: 0.23, blue: 0.18)
        case .ink: return Color(red: 0.85, green: 0.85, blue: 0.85)
        case .forest: return Color(red: 0.48, green: 0.85, blue: 0.62)
        }
    }
}

// MARK: - 沉浸模式控制器

@MainActor
final class ImmersiveReaderController {
    static let shared = ImmersiveReaderController()
    private var panel: NSPanel?

    func present(note: ReadingNote) {
        dismiss()

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        p.isReleasedWhenClosed = false
        p.level = .modalPanel
        p.backgroundColor = .black
        p.isOpaque = true
        p.hasShadow = false
        p.collectionBehavior = [.fullScreenPrimary, .managed]
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.contentView = NSHostingView(
            rootView: ImmersiveReaderView(note: note) {
                self.dismiss()
            }
            .environment(ThemeStore.shared)
            .themePalette(ThemeStore.shared.palette)
        )
        if let screen = NSScreen.main {
            p.setFrame(screen.frame, display: true)
        }
        p.makeKeyAndOrderFront(nil)
        panel = p
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}