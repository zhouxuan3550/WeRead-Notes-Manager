import SwiftUI

// MARK: - 数字滚动动画
//
// 让数字从 0 滚动到目标值，搭配 spring 弹性曲线。
// 比直接显示数字更有"生命感"。

// MARK: - 数字滚动

struct AnimatedNumber: View {
    let targetValue: Int
    let duration: Double
    let font: Font
    let color: Color

    @State private var displayValue: Int = 0
    @State private var animationTask: Task<Void, Never>?

    init(targetValue: Int, duration: Double = 1.2, font: Font = .system(size: 32, weight: .bold), color: Color = .primary) {
        self.targetValue = targetValue
        self.duration = duration
        self.font = font
        self.color = color
    }

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(displayValue)))
            .onAppear { animate() }
            .onChange(of: targetValue) { _, _ in animate() }
    }

    private func animate() {
        animationTask?.cancel()
        animationTask = Task {
            let steps = 30
            let stepDuration = duration / Double(steps)

            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                let progress = Double(step) / Double(steps)
                // 使用 ease-out 曲线
                let eased = 1 - pow(1 - progress, 3)
                let value = Int(Double(targetValue) * eased)
                await MainActor.run {
                    displayValue = value
                }
            }
            await MainActor.run {
                displayValue = targetValue
            }
        }
    }
}

// MARK: - 百分比环动画

struct AnimatedProgressRing: View {
    let progress: Double  // 0.0 - 1.0
    let lineWidth: CGFloat
    let color: Color
    let backgroundColor: Color

    @State private var animatedProgress: Double = 0

    init(progress: Double, lineWidth: CGFloat = 6, color: Color = .accentColor, backgroundColor: Color = Color.gray.opacity(0.2)) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                animatedProgress = new
            }
        }
    }
}

// MARK: - 进度条（横版）

struct AnimatedProgressBar: View {
    let progress: Double
    let height: CGFloat
    let color: Color

    @State private var animatedProgress: Double = 0

    init(progress: Double, height: CGFloat = 8, color: Color = .accentColor) {
        self.progress = progress
        self.height = height
        self.color = color
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.background.opacity(0.5))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(2, geo.size.width * animatedProgress))
                    .shadow(color: color.opacity(0.4), radius: 4)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = new
            }
        }
    }

    @Environment(\.themePalette) private var palette
}

// MARK: - 计数器组（多个数字一起动画）

struct AnimatedStatGrid: View {
    let stats: [StatItem]

    struct StatItem: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
        let color: Color
        let systemImage: String
    }

    @State private var animationDelay: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                statCard(stat, index: index)
            }
        }
        .onAppear {
            animationDelay = 0
        }
    }

    private func statCard(_ stat: StatItem, index: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: stat.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(stat.color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(stat.color.opacity(0.15)))

            AnimatedNumber(
                targetValue: stat.value,
                duration: 1.0 + Double(index) * 0.15,
                font: .system(size: 24, weight: .bold, design: .rounded),
                color: stat.color
            )
            .frame(minHeight: 28)

            Text(stat.label)
                .font(Typography.micro)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(stat.color.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - 倒计时

struct CountdownLabel: View {
    let targetDate: Date
    let prefix: String

    @State private var now = Date()
    @State private var timer: Timer?

    var body: some View {
        Text("\(prefix) \(timeString)")
            .font(Typography.mono)
            .monospacedDigit()
            .onAppear { startTimer() }
            .onDisappear { stopTimer() }
    }

    private var timeString: String {
        let interval = max(0, Int(targetDate.timeIntervalSince(now)))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            now = Date()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
    }
}