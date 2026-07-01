import SwiftUI

// MARK: - 3D 翻转闪卡
//
// - rotation3DEffect 实现 Y 轴 3D 翻转
// - 正面：原文划线
// - 反面：用户想法 + 章节上下文
// - 翻转有 spring 弹性，配以微光扫过

struct FlipCardView: View {
    let note: ReadingNote
    let isFlipped: Bool

    @Environment(\.themePalette) private var palette
    @State private var shineOffset: CGFloat = -1.0

    var body: some View {
        ZStack {
            // 正面
            cardFace(isFlipped: false)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.6
                )

            // 反面
            cardFace(isFlipped: true)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.6
                )
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 320)
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: isFlipped)
    }

    @ViewBuilder
    private func cardFace(isFlipped: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // 顶部：书籍 + 章节
            HStack(alignment: .top, spacing: 12) {
                if let book = note.book {
                    BookCoverView(book: book, size: .medium)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(book.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(2)
                        Text([book.author, note.chapter].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 12))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: isFlipped ? "lightbulb.fill" : "quote.opening")
                    .font(.system(size: 16))
                    .foregroundStyle(isFlipped ? palette.warning : palette.accent)
            }

            Divider().background(palette.borderSubtle)

            // 主内容
            if isFlipped {
                // 反面：用户想法
                VStack(alignment: .leading, spacing: 12) {
                    Text("你的想法")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                        .textCase(.uppercase)

                    if let userNote = note.userNote, !userNote.isEmpty {
                        Text(userNote)
                            .font(.serifBody)
                            .lineSpacing(5)
                            .foregroundStyle(palette.textPrimary)
                    } else {
                        Text("（这条笔记没有想法）")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.textTertiary)
                            .italic()
                    }

                    // 底部参考原文
                    VStack(alignment: .leading, spacing: 4) {
                        Text("原文")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.textTertiary)
                            .textCase(.uppercase)
                        Text(note.highlight)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(4)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(palette.surface.opacity(0.5))
                    )
                }
            } else {
                // 正面：原文
                ScrollView {
                    Text(note.highlight)
                        .font(.serifTitle)
                        .lineSpacing(7)
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                .frame(maxHeight: 200)
            }

            Spacer(minLength: 0)

            // 底部提示
            HStack {
                Image(systemName: isFlipped ? "arrow.uturn.backward" : "hand.tap")
                    .font(.system(size: 11))
                Text(isFlipped ? "点击翻回" : "点击翻转")
                    .font(.system(size: 11))
            }
            .foregroundStyle(palette.textTertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        .background(
            ZStack {
                // 渐变背景
                LinearGradient(
                    colors: [
                        palette.surfaceElevated,
                        palette.surface.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Mesh 点缀
                RadialGradient(
                    colors: [palette.accent.opacity(0.10), Color.clear],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 220
                )

                // 微光扫过
                if !isFlipped {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: shineOffset * 400)
                    .blendMode(.plusLighter)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shineOffset = 1.5
            }
        }
    }
}

// MARK: - 评级粒子动画

struct GradeParticles: View {
    let grade: ReviewGrade
    let trigger: Bool

    @Environment(\.themePalette) private var palette
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var life: CGFloat = 1.0
        var symbol: String
        var color: Color
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Image(systemName: p.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(p.color)
                    .opacity(p.life)
                    .offset(x: p.x, y: p.y)
                    .scaleEffect(p.life)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, newValue in
            if newValue {
                burst()
            }
        }
    }

    private func burst() {
        let count = 16
        let symbols: [String]
        let color: Color

        switch grade {
        case .again:
            symbols = ["xmark", "xmark.circle.fill"]
            color = palette.error
        case .hard:
            symbols = ["minus.circle.fill"]
            color = palette.warning
        case .good:
            symbols = ["checkmark", "checkmark.circle.fill"]
            color = palette.success
        case .easy:
            symbols = ["star.fill", "sparkles"]
            color = palette.accent
        }

        particles = (0..<count).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 80...180)
            return Particle(
                x: 0,
                y: 0,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed - 80,
                symbol: symbols.randomElement() ?? "sparkles",
                color: color
            )
        }

        // 帧驱动
        let timer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
        var ticks = 0
        let cancellable = timer.sink { _ in
            ticks += 1
            withAnimation(.linear(duration: 0.016)) {
                particles = particles.map { p in
                    var p = p
                    p.x += p.vx * 0.016
                    p.y += p.vy * 0.016
                    p.vy += 320 * 0.016  // 重力
                    p.life = max(0, p.life - 0.025)
                    return p
                }
            }
            if ticks > 60 {
                particles = []
            }
        }
        // 1 秒后清理
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            cancellable.cancel()
            particles = []
        }
    }
}

// MARK: - 评级按钮（带粒子触发）

struct GradeButton: View {
    let grade: ReviewGrade
    let action: () -> Void

    @Environment(\.themePalette) private var palette
    @State private var isHovering = false
    @State private var burstTrigger = false

    var body: some View {
        Button {
            burstTrigger.toggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: grade.systemImage)
                    .font(.system(size: 18))
                Text(grade.label)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(width: 84)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(isHovering ? 0.25 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(color.opacity(isHovering ? 0.8 : 0.5), lineWidth: 1)
            )
            .foregroundStyle(color)
            .scaleEffect(isHovering ? 1.06 : 1)
            .animation(DesignSystem.Animation.fast, value: isHovering)
        }
        .buttonStyle(.plain)
        .overlay(GradeParticles(grade: grade, trigger: burstTrigger))
        .onHover { isHovering = $0 }
    }

    private var color: Color {
        switch grade {
        case .again: return palette.error
        case .hard: return palette.warning
        case .good: return palette.success
        case .easy: return palette.accent
        }
    }
}