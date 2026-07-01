import AppKit
import SwiftUI
import SwiftData
import Combine

// MARK: - 剪贴板监听器
//
// 后台监听系统剪贴板变化：
// - 复制文字 → 顶部弹出"保存为笔记？"气泡
// - 复制图片 → 顶部弹出"保存图片笔记？"
// - 复制 URL → 顶部弹出"打开 / 保存"
// - 去重：相同内容 60 秒内只弹一次

@MainActor
@Observable
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    var pending: PendingItem?
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "clipboardMonitorEnabled") }
    }

    struct PendingItem: Identifiable {
        let id = UUID()
        let text: String?
        let image: NSImage?
        let url: URL?
        let timestamp: Date
    }

    private var pollTimer: Timer?
    private var lastText: String?
    private var lastImageHash: Int?
    private var lastURL: String?

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "clipboardMonitorEnabled") as? Bool ?? true
    }

    func startMonitoring() {
        guard isEnabled else { return }
        stopMonitoring()
        // 启动后第一次轮询取当前剪贴板作为基准
        captureBaseline()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func dismiss() {
        pending = nil
    }

    // MARK: - 私有

    private func captureBaseline() {
        let pb = NSPasteboard.general
        lastText = pb.string(forType: .string)
        lastImageHash = pb.data(forType: .tiff)?.hashValue
        lastURL = pb.string(forType: .URL)
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general

        // 1. 图片
        if let imgData = pb.data(forType: .tiff) {
            let h = imgData.hashValue
            if h != lastImageHash {
                lastImageHash = h
                if let img = NSImage(data: imgData) {
                    pending = PendingItem(text: nil, image: img, url: nil, timestamp: .now)
                    return
                }
            }
        }

        // 2. URL
        if let urlString = pb.string(forType: .URL), urlString != lastURL {
            lastURL = urlString
            if let url = URL(string: urlString), url.scheme != nil {
                pending = PendingItem(text: nil, image: nil, url: url, timestamp: .now)
                return
            }
        }

        // 3. 文本
        if let text = pb.string(forType: .string), !text.isEmpty, text != lastText {
            lastText = text
            // 过滤太短 / 太长 / 看起来不像笔记的
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 4 && trimmed.count <= 5000 {
                // 60 秒内同内容不重复
                if pending?.text != text || (Date().timeIntervalSince(pending?.timestamp ?? .distantPast) > 60) {
                    pending = PendingItem(text: text, image: nil, url: nil, timestamp: .now)
                }
            }
        }
    }
}

// MARK: - 气泡视图

struct ClipboardBubbleView: View {
    let item: ClipboardMonitor.PendingItem
    let onSaveText: (String) -> Void
    let onSaveImage: (NSImage) -> Void
    let onOpenURL: (URL) -> Void
    let onDismiss: () -> Void

    @Environment(\.themePalette) private var palette
    @State private var animateIn = false

    var body: some View {
        HStack(spacing: 10) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(preview)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button("忽略", action: onDismiss)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button(actionLabel, systemImage: "tray.and.arrow.down", action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.accent.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .offset(y: animateIn ? 0 : 80)
        .opacity(animateIn ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                animateIn = true
            }
        }
    }

    private var icon: some View {
        ZStack {
            Circle().fill(palette.accent.opacity(0.18))
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
        .frame(width: 32, height: 32)
    }

    private var iconName: String {
        if item.image != nil { return "photo" }
        if item.url != nil { return "link" }
        return "doc.on.clipboard"
    }

    private var title: String {
        if item.image != nil { return "检测到剪贴板图片" }
        if item.url != nil { return "检测到链接" }
        return "检测到剪贴板文字"
    }

    private var preview: String {
        if let text = item.text {
            return String(text.prefix(80))
        }
        if let url = item.url {
            return url.absoluteString
        }
        return "图片已复制"
    }

    private var actionLabel: String {
        if item.image != nil { return "保存图片" }
        if item.url != nil { return "打开链接" }
        return "保存为笔记"
    }

    private func primaryAction() {
        if let text = item.text {
            onSaveText(text)
        } else if let img = item.image {
            onSaveImage(img)
        } else if let url = item.url {
            onOpenURL(url)
        }
    }
}

extension View {
    func clipboardBubble(
        onSaveText: @escaping (String) -> Void,
        onSaveImage: @escaping (NSImage) -> Void,
        onOpenURL: @escaping (URL) -> Void
    ) -> some View {
        overlay(alignment: .bottom) {
            if let item = ClipboardMonitor.shared.pending {
                ClipboardBubbleView(
                    item: item,
                    onSaveText: onSaveText,
                    onSaveImage: onSaveImage,
                    onOpenURL: onOpenURL,
                    onDismiss: { ClipboardMonitor.shared.dismiss() }
                )
            }
        }
    }
}