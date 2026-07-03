import Foundation
import SwiftUI
import AppKit
import Combine
import UserNotifications

// MARK: - 番茄钟（专注计时器）
//
// 阅读时启动番茄钟：
// - 默认 25 分钟（可配置）
// - 进度环 + 时间显示
// - 到点系统通知 + 声音提示
// - 自动记录到成就系统（每日阅读时长）

@MainActor
@Observable
final class PomodoroTimer {
    static let shared = PomodoroTimer()

    enum State: String {
        case idle       // 未启动
        case running    // 进行中
        case paused     // 暂停
        case finished   // 完成
    }

    var state: State = .idle
    var workMinutes: Int = 25
    var breakMinutes: Int = 5

    var startDate: Date?
    var pausedSeconds: TimeInterval = 0
    var lastPauseDate: Date?

    var totalFocusSeconds: Int = 0  // 累计专注秒数
    var todayFocusSeconds: Int = 0

    private var timer: Timer?

    private init() {
        loadTodayStats()
    }

    // MARK: - 控制

    func start(workMinutes: Int = 25) {
        self.workMinutes = workMinutes
        state = .running
        startDate = Date()
        pausedSeconds = 0
        lastPauseDate = nil
        scheduleTimer()
        ErrorPresenter.shared.showInfo("🍅 番茄钟启动，专注 \(workMinutes) 分钟")
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        lastPauseDate = Date()
        timer?.invalidate()
    }

    func resume() {
        guard state == .paused, let last = lastPauseDate else { return }
        pausedSeconds += Date().timeIntervalSince(last)
        lastPauseDate = nil
        state = .running
        scheduleTimer()
    }

    func stop() {
        let elapsed = currentElapsed
        if elapsed > 0 {
            todayFocusSeconds += Int(elapsed)
            saveTodayStats()
            ErrorPresenter.shared.showInfo("已专注 \(formatTime(elapsed))")
        }
        timer?.invalidate()
        timer = nil
        startDate = nil
        pausedSeconds = 0
        lastPauseDate = nil
        state = .idle
    }

    // MARK: - 计时

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard state == .running else { return }
        let elapsed = currentElapsed
        let target = TimeInterval(workMinutes * 60)
        if elapsed >= target {
            finish()
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        state = .finished

        // 累计专注时长
        todayFocusSeconds += workMinutes * 60
        saveTodayStats()

        // 系统通知
        sendCompletionNotification()

        // 声音提示
        NSSound.beep()

        ErrorPresenter.shared.showInfo("✅ 番茄钟完成！专注 \(workMinutes) 分钟")
    }

    // MARK: - 状态查询

    var currentElapsed: TimeInterval {
        guard let start = startDate else { return 0 }
        var elapsed = Date().timeIntervalSince(start) - pausedSeconds
        if let pause = lastPauseDate {
            elapsed -= Date().timeIntervalSince(pause)
        }
        return max(0, elapsed)
    }

    var remainingSeconds: TimeInterval {
        let target = TimeInterval(workMinutes * 60)
        return max(0, target - currentElapsed)
    }

    var progress: Double {
        let target = Double(workMinutes * 60)
        guard target > 0 else { return 0 }
        return min(1.0, currentElapsed / target)
    }

    var elapsedFormatted: String { formatTime(currentElapsed) }
    var remainingFormatted: String { formatTime(remainingSeconds) }

    private func formatTime(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: - 通知

    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🍅 番茄钟完成"
        content.body = "专注 \(workMinutes) 分钟，是时候休息一下了。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "pomodoro.completed.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    // MARK: - 今日统计

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func loadTodayStats() {
        let stored = UserDefaults.standard.integer(forKey: "pomodoro.\(todayKey)")
        todayFocusSeconds = stored
    }

    private func saveTodayStats() {
        UserDefaults.standard.set(todayFocusSeconds, forKey: "pomodoro.\(todayKey)")
    }
}

// MARK: - 番茄钟 UI

struct PomodoroWidget: View {
    @State private var timer = PomodoroTimer.shared
    @State private var showCustomDialog = false
    @State private var customMinutes: String = "25"

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(spacing: 14) {
            // 进度环
            ZStack {
                Circle()
                    .stroke(palette.borderSubtle, lineWidth: 6)

                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(
                        LinearGradient(
                            colors: [palette.accent, palette.warning],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.progress)

                VStack(spacing: 2) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(stateColor)
                    Text(timer.state == .running ? timer.remainingFormatted : timer.elapsedFormatted)
                        .font(.system(size: 22, weight: .bold, design: .monospaced).monospacedDigit())
                        .foregroundStyle(palette.textPrimary)
                    Text(stateLabel)
                        .font(Typography.micro)
                        .foregroundStyle(palette.textTertiary)
                }
            }
            .frame(width: 140, height: 140)

            // 控制按钮
            HStack(spacing: 8) {
                switch timer.state {
                case .idle, .finished:
                    Button {
                        timer.start(workMinutes: Int(customMinutes) ?? 25)
                    } label: {
                        Label("开始", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .flatActionButton(.accent, height: 32)
                case .running:
                    Button {
                        timer.pause()
                    } label: {
                        Label("暂停", systemImage: "pause.fill")
                    }
                    .flatActionButton(height: 32)

                    Button {
                        timer.stop()
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                    }
                    .flatActionButton(height: 32)
                case .paused:
                    Button {
                        timer.resume()
                    } label: {
                        Label("继续", systemImage: "play.fill")
                    }
                    .flatActionButton(.accent, height: 32)

                    Button {
                        timer.stop()
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                    }
                    .flatActionButton(height: 32)
                }
            }

            // 时长配置
            if timer.state == .idle {
                HStack(spacing: 4) {
                    ForEach([15, 25, 45, 60], id: \.self) { mins in
                        Button("\(mins)分") {
                            customMinutes = "\(mins)"
                            timer.start(workMinutes: mins)
                        }
                        .flatActionButton(height: 32)
                        .controlSize(.small)
                    }
                }
            }

            // 今日统计
            Text("今日专注：\(formatTotal(timer.todayFocusSeconds))")
                .font(Typography.micro)
                .foregroundStyle(palette.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.borderSubtle, lineWidth: 0.5)
        )
    }

    private var stateColor: Color {
        switch timer.state {
        case .running: return palette.success
        case .paused: return palette.warning
        case .finished: return palette.accent
        case .idle: return palette.textTertiary
        }
    }

    private var stateLabel: String {
        switch timer.state {
        case .running: return "专注中"
        case .paused: return "已暂停"
        case .finished: return "已完成"
        case .idle: return "准备开始"
        }
    }

    private func formatTotal(_ seconds: Int) -> String {
        let mins = seconds / 60
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins) 分钟"
    }
}

// MARK: - 悬浮番茄钟（菜单栏）

@MainActor
final class PomodoroFloatingController {
    static let shared = PomodoroFloatingController()
    private var panel: NSPanel?

    func toggle() {
        if panel != nil {
            panel?.orderOut(nil)
            panel = nil
        } else {
            show()
        }
    }

    func show() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 240),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.isReleasedWhenClosed = false
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.contentView = NSHostingView(
            rootView: PomodoroWidget()
                .environment(ThemeStore.shared)
                .themePalette(ThemeStore.shared.palette)
        )
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            p.setFrameOrigin(NSPoint(
                x: screenFrame.midX - 140,
                y: screenFrame.midY - 120
            ))
        }
        p.makeKeyAndOrderFront(nil)
        panel = p
    }
}