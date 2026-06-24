import AppKit
import SwiftUI
import SwiftData

@main
struct WeReadNotesManagerApp: App {
    let container: ModelContainer

    @State private var quickCaptureWindow: NSWindow?
    @State private var globalHotKeyRef: Any?

    init() {
        do {
            container = try ModelContainer(for: Book.self, ReadingNote.self, ImportRecord.self, Tag.self, BookSummary.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(.dark)
                .background(WindowChromeApplier())
        }
        .modelContainer(container)
        .windowStyle(.titleBar)
        .defaultSize(width: 1060, height: 680)
        .commands {
            // 用 ⌘N 触发 Quick Capture（macOS 上 NSDocument 一般占用 ⌘N，新建文档场景不合适）
            CommandGroup(after: .newItem) {
                Button("快速记录...") {
                    showQuickCapture()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }

        // 菜单栏常驻图标（Feature 7）
        MenuBarExtra("书摘温故", systemImage: "books.vertical") {
            Button("快速记录...") {
                showQuickCapture()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("显示主窗口") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Button("退出") {
                NSApp.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }

    /// 弹出 Quick Capture 窗口。
    private func showQuickCapture() {
        // 已有窗口则前置
        if let existing = quickCaptureWindow {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "快速记录"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: QuickCaptureView()
                .modelContainer(container)
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        quickCaptureWindow = window
    }
}

/// 把窗口标题栏配置下放到 AppKit 一次性完成。
private struct WindowChromeApplier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            applyChrome(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // 不再每次 update 都重新派发。
    }

    private func applyChrome(to window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar?.isVisible = false
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
    }
}