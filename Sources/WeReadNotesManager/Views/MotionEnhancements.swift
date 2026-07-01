import SwiftUI

// MARK: - 微动效工具集
//
// 收集可复用的动效修饰符：
// - pressable: 按下时缩放反馈
// - shimmer: 微光扫过（加载/高亮）
// - floatingShadow: 浮动阴影
// - matchedGeometryEffect: 共享元素 ID 助手
// - parallaxScroll: 滚动视差

// MARK: - 按下缩放

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    /// 缩放反馈按钮样式。
    func pressable() -> some View {
        buttonStyle(PressableStyle())
    }
}

// MARK: - 微光扫过

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0
    let speed: Double
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if enabled {
                        LinearGradient(
                            colors: [
                                .white.opacity(0),
                                .white.opacity(0.18),
                                .white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: phase * geo.size.width * 1.2)
                        .blendMode(.plusLighter)
                        .onAppear {
                            withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                                phase = 1.5
                            }
                        }
                    }
                }
            )
            .clipped()
    }
}

extension View {
    /// 添加一道扫过的微光（用于骨架屏/加载态）。
    func shimmer(speed: Double = 2.4, enabled: Bool = true) -> some View {
        modifier(ShimmerModifier(speed: speed, enabled: enabled))
    }
}

// MARK: - 浮动阴影

struct FloatingShadowModifier: ViewModifier {
    @Environment(\.themePalette) private var palette
    let intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: palette.accent.opacity(0.10 * intensity),
                    radius: 16 * intensity, y: 6 * intensity)
            .shadow(color: .black.opacity(0.10 * intensity),
                    radius: 8 * intensity, y: 2 * intensity)
    }
}

extension View {
    func floatingShadow(intensity: CGFloat = 1) -> some View {
        modifier(FloatingShadowModifier(intensity: intensity))
    }
}

// MARK: - 滚动视差

struct ParallaxScrollModifier: ViewModifier {
    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    let offset = geo.frame(in: .named("parallax")).minY
                    Color.clear
                        .onChange(of: offset) { _, new in
                            scrollOffset = new
                        }
                }
            )
    }
}

extension View {
    func parallaxScroll() -> some View {
        modifier(ParallaxScrollModifier())
    }
}

// MARK: - 旋转入场动画

struct RotateInModifier: ViewModifier {
    let delay: Double
    let duration: Double
    @State private var rotation: Double = -8
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    rotation = 0
                    opacity = 1
                }
            }
    }
}

extension View {
    func rotateIn(delay: Double = 0, duration: Double = 0.5) -> some View {
        modifier(RotateInModifier(delay: delay, duration: duration))
    }
}

// MARK: - 列表项依次入场

struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 12)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * baseDelay)) {
                    visible = true
                }
            }
    }
}

extension View {
    /// 列表项依次入场：第 N 个延迟 N * baseDelay 秒
    func staggeredAppear(index: Int, baseDelay: Double = 0.04) -> some View {
        modifier(StaggeredAppearModifier(index: index, baseDelay: baseDelay))
    }
}

// MARK: - Matched Geometry 助手

/// 用于跨 View 共享元素动画的命名空间类型。
/// 用法：
///   @Namespace var animation
///   Image("cover").matchedGeometryEffect(id: book.id, in: animation)
enum MatchedNamespace {
    static let bookCover = "WeRead.BookCover"
    static let noteTitle = "WeRead.NoteTitle"
    static let tag = "WeRead.Tag"
}

// MARK: - 渐显计数器动画

struct AnimatedCounter: View {
    let value: Int
    let font: Font
    let color: Color

    @State private var displayValue: Int = 0

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .onAppear {
                displayValue = 0
                animate(to: value)
            }
            .onChange(of: value) { _, new in
                animate(to: new)
            }
    }

    private func animate(to target: Int) {
        let steps = 20
        let stepDuration = 0.6 / Double(steps)
        let diff = target - displayValue
        let stepSize = max(1, diff / steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                if i == steps {
                    displayValue = target
                } else {
                    displayValue += stepSize
                }
            }
        }
    }
}

// MARK: - 抖动反馈

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3.0
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * Double.pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

extension View {
    /// 抖动（错误反馈）。
    func shake(trigger: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(trigger)))
    }
}

// MARK: - Hover 提升光

struct HoverGlowModifier: ViewModifier {
    @Environment(\.themePalette) private var palette
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .shadow(color: palette.accent.opacity(hovering ? 0.4 : 0),
                    radius: hovering ? 16 : 0)
            .scaleEffect(hovering ? 1.02 : 1)
            .animation(DesignSystem.Animation.fast, value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverGlow() -> some View {
        modifier(HoverGlowModifier())
    }
}