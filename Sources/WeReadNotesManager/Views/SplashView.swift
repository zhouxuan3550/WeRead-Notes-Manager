import SwiftUI
import AppKit

// MARK: - 启动页
//
// macOS App 启动时展示的闪屏：
// - Logo Mesh Gradient 动画
// - 主题色光晕
// - 3 秒后自动消失（或加载完成后消失）

struct SplashView: View {
    let onComplete: () -> Void
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.85
    @State private var rotation: Double = -8

    @Environment(\.themePalette) private var palette

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            // 光晕
            RadialGradient(
                colors: [palette.accent.opacity(0.30), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: palette.meshColors,
                                        center: .center,
                                        startRadius: 5,
                                        endRadius: 80
                                    )
                                )
                        )
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                                rotation = 8
                            }
                        }
                        .shadow(color: palette.accent.opacity(0.4), radius: 30, y: 12)

                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                }
                .scaleEffect(scale)

                VStack(spacing: 8) {
                    Text("书摘温故")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(palette.textPrimary)

                    Text("WeRead Notes Manager")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .tracking(2)
                }

                // 加载条
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 6, height: 6)
                            .scaleEffect(scale)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15),
                                value: scale
                            )
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1
                scale = 1
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                withAnimation(.easeIn(duration: 0.4)) {
                    opacity = 0
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
                onComplete()
            }
        }
    }
}

// MARK: - 启动窗口控制器

@MainActor
final class SplashWindowController {
    static let shared = SplashWindowController()
    private var window: NSWindow?

    func show() {
        guard window == nil else { return }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        w.level = .floating
        w.center()
        w.contentView = NSHostingView(
            rootView: SplashView { [weak self] in
                self?.dismiss()
            }
            .environment(ThemeStore.shared)
            .themePalette(ThemeStore.shared.palette)
        )
        w.makeKeyAndOrderFront(nil)
        window = w
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}