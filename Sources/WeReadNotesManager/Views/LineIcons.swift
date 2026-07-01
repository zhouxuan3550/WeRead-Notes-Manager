import SwiftUI

// MARK: - 自绘线性图标库
//
// 用 SwiftUI Path 绘制线性风格图标，替代 SF Symbols 实心。
// 风格：1.5pt 描边，圆角 line cap，圆角 line join，
// 模仿 Feather Icons / Lucide Icons 风格。
//
// 优势：
// - 完全可控的颜色 / 粗细 / 圆角
// - 比 SF Symbols 更精致（避免 emoji 感）
// - 主题色自动适配

// MARK: - 基础图标视图

struct LineIcon: View {
    let path: Path
    var size: CGFloat = 18
    var strokeWidth: CGFloat = 1.5
    var color: Color = .primary

    var body: some View {
        GeometryReader { proxy in
            path
                .applying(CGAffineTransform(
                    scaleX: proxy.size.width / 24,
                    y: proxy.size.height / 24
                ))
                .stroke(color, style: StrokeStyle(
                    lineWidth: strokeWidth,
                    lineCap: .round,
                    lineJoin: .round
                ))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 图标路径构造器

enum LineIconPath {
    static func book() -> Path {
        // 一本打开的书
        var p = Path()
        p.move(to: CGPoint(x: 3, y: 4))
        p.addLine(to: CGPoint(x: 3, y: 20))
        p.addLine(to: CGPoint(x: 12, y: 20))
        p.addLine(to: CGPoint(x: 12, y: 4))
        p.addLine(to: CGPoint(x: 12, y: 20))
        p.addLine(to: CGPoint(x: 21, y: 20))
        p.addLine(to: CGPoint(x: 21, y: 4))
        p.addLine(to: CGPoint(x: 12, y: 4))
        return p
    }

    static func library() -> Path {
        // 书架
        var p = Path()
        p.addRect(CGRect(x: 3, y: 3, width: 18, height: 18))
        p.move(to: CGPoint(x: 7, y: 21))
        p.addLine(to: CGPoint(x: 7, y: 8))
        p.move(to: CGPoint(x: 11, y: 21))
        p.addLine(to: CGPoint(x: 11, y: 11))
        p.move(to: CGPoint(x: 15, y: 21))
        p.addLine(to: CGPoint(x: 15, y: 7))
        return p
    }

    static func search() -> Path {
        // 放大镜
        var p = Path()
        p.addEllipse(in: CGRect(x: 3, y: 3, width: 14, height: 14))
        p.move(to: CGPoint(x: 14.5, y: 14.5))
        p.addLine(to: CGPoint(x: 21, y: 21))
        return p
    }

    static func bookmark() -> Path {
        // 书签
        var p = Path()
        p.move(to: CGPoint(x: 6, y: 3))
        p.addLine(to: CGPoint(x: 18, y: 3))
        p.addLine(to: CGPoint(x: 18, y: 21))
        p.addLine(to: CGPoint(x: 12, y: 17))
        p.addLine(to: CGPoint(x: 6, y: 21))
        p.closeSubpath()
        return p
    }

    static func sparkle() -> Path {
        // 星星（4 角）
        var p = Path()
        let center = CGPoint(x: 12, y: 12)
        let outer: CGFloat = 8
        let inner: CGFloat = 3.5

        // 8 个点画 4 角星
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            let r = i % 2 == 0 ? outer : inner
            let x = center.x + CGFloat(cos(angle)) * r
            let y = center.y + CGFloat(sin(angle)) * r
            if i == 0 {
                p.move(to: CGPoint(x: x, y: y))
            } else {
                p.addLine(to: CGPoint(x: x, y: y))
            }
        }
        p.closeSubpath()
        return p
    }

    static func layers() -> Path {
        // 层叠方块（主题地图）
        var p = Path()
        p.addRect(CGRect(x: 3, y: 3, width: 12, height: 12))
        p.move(to: CGPoint(x: 9, y: 9))
        p.addLine(to: CGPoint(x: 21, y: 9))
        p.addLine(to: CGPoint(x: 21, y: 21))
        p.addLine(to: CGPoint(x: 9, y: 21))
        p.closeSubpath()
        return p
    }

    static func chart() -> Path {
        // 柱状图
        var p = Path()
        p.move(to: CGPoint(x: 3, y: 21))
        p.addLine(to: CGPoint(x: 21, y: 21))
        p.move(to: CGPoint(x: 6, y: 17))
        p.addLine(to: CGPoint(x: 6, y: 13))
        p.move(to: CGPoint(x: 11, y: 17))
        p.addLine(to: CGPoint(x: 11, y: 9))
        p.move(to: CGPoint(x: 16, y: 17))
        p.addLine(to: CGPoint(x: 16, y: 11))
        return p
    }

    static func quote() -> Path {
        // 引号
        var p = Path()
        // 左引号
        p.move(to: CGPoint(x: 6, y: 9))
        p.addCurve(to: CGPoint(x: 3, y: 9), control1: CGPoint(x: 6, y: 6), control2: CGPoint(x: 3, y: 6))
        p.addLine(to: CGPoint(x: 3, y: 18))
        p.addLine(to: CGPoint(x: 9, y: 18))
        p.addLine(to: CGPoint(x: 9, y: 9))
        p.closeSubpath()
        // 右引号
        p.move(to: CGPoint(x: 18, y: 9))
        p.addCurve(to: CGPoint(x: 15, y: 9), control1: CGPoint(x: 18, y: 6), control2: CGPoint(x: 15, y: 6))
        p.addLine(to: CGPoint(x: 15, y: 18))
        p.addLine(to: CGPoint(x: 21, y: 18))
        p.addLine(to: CGPoint(x: 21, y: 9))
        p.closeSubpath()
        return p
    }

    static func brain() -> Path {
        // 思维导图（脑图）
        var p = Path()
        // 左半脑
        p.move(to: CGPoint(x: 12, y: 4))
        p.addCurve(to: CGPoint(x: 4, y: 7), control1: CGPoint(x: 8, y: 3), control2: CGPoint(x: 4, y: 4))
        p.addCurve(to: CGPoint(x: 4, y: 17), control1: CGPoint(x: 4, y: 10), control2: CGPoint(x: 4, y: 14))
        p.addCurve(to: CGPoint(x: 12, y: 20), control1: CGPoint(x: 4, y: 20), control2: CGPoint(x: 8, y: 21))
        // 右半脑
        p.move(to: CGPoint(x: 12, y: 4))
        p.addCurve(to: CGPoint(x: 20, y: 7), control1: CGPoint(x: 16, y: 3), control2: CGPoint(x: 20, y: 4))
        p.addCurve(to: CGPoint(x: 20, y: 17), control1: CGPoint(x: 20, y: 10), control2: CGPoint(x: 20, y: 14))
        p.addCurve(to: CGPoint(x: 12, y: 20), control1: CGPoint(x: 20, y: 20), control2: CGPoint(x: 16, y: 21))
        return p
    }

    static func trash() -> Path {
        var p = Path()
        // 桶身
        p.move(to: CGPoint(x: 4, y: 7))
        p.addLine(to: CGPoint(x: 20, y: 7))
        p.move(to: CGPoint(x: 6, y: 7))
        p.addLine(to: CGPoint(x: 6, y: 21))
        p.addLine(to: CGPoint(x: 18, y: 21))
        p.addLine(to: CGPoint(x: 18, y: 7))
        // 把手
        p.move(to: CGPoint(x: 9, y: 7))
        p.addLine(to: CGPoint(x: 9, y: 4))
        p.addLine(to: CGPoint(x: 15, y: 4))
        p.addLine(to: CGPoint(x: 15, y: 7))
        return p
    }

    static func gear() -> Path {
        // 设置（齿轮简笔）
        var p = Path()
        let center = CGPoint(x: 12, y: 12)
        let outer: CGFloat = 7
        let inner: CGFloat = 4

        // 8 齿
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4 + .pi / 8
            let x1 = center.x + CGFloat(cos(angle)) * outer
            let y1 = center.y + CGFloat(sin(angle)) * outer
            let x2 = center.x + CGFloat(cos(angle)) * (outer + 2)
            let y2 = center.y + CGFloat(sin(angle)) * (outer + 2)
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
        }
        // 中心圆
        p.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
        return p
    }

    static func home() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 3, y: 11))
        p.addLine(to: CGPoint(x: 12, y: 3))
        p.addLine(to: CGPoint(x: 21, y: 11))
        p.move(to: CGPoint(x: 5, y: 10))
        p.addLine(to: CGPoint(x: 5, y: 21))
        p.addLine(to: CGPoint(x: 19, y: 21))
        p.addLine(to: CGPoint(x: 19, y: 10))
        return p
    }

    static func tag() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 20, y: 13))
        p.addLine(to: CGPoint(x: 13, y: 20))
        p.addLine(to: CGPoint(x: 4, y: 20))
        p.addLine(to: CGPoint(x: 4, y: 11))
        p.addLine(to: CGPoint(x: 11, y: 4))
        p.addLine(to: CGPoint(x: 20, y: 4))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: 15, y: 8, width: 2, height: 2))
        return p
    }

    static func stack() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 12, y: 3))
        p.addLine(to: CGPoint(x: 21, y: 7))
        p.addLine(to: CGPoint(x: 21, y: 17))
        p.addLine(to: CGPoint(x: 12, y: 21))
        p.addLine(to: CGPoint(x: 3, y: 17))
        p.addLine(to: CGPoint(x: 3, y: 7))
        p.closeSubpath()
        p.move(to: CGPoint(x: 12, y: 12))
        p.addLine(to: CGPoint(x: 21, y: 7))
        p.move(to: CGPoint(x: 3, y: 7))
        p.addLine(to: CGPoint(x: 12, y: 12))
        return p
    }

    static func heart() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 12, y: 21))
        p.addCurve(to: CGPoint(x: 3, y: 12), control1: CGPoint(x: 7, y: 21), control2: CGPoint(x: 3, y: 17))
        p.addCurve(to: CGPoint(x: 3, y: 7), control1: CGPoint(x: 3, y: 10), control2: CGPoint(x: 5, y: 7))
        p.addCurve(to: CGPoint(x: 9, y: 7), control1: CGPoint(x: 7, y: 7), control2: CGPoint(x: 9, y: 8))
        p.addLine(to: CGPoint(x: 12, y: 10))
        p.addLine(to: CGPoint(x: 15, y: 7))
        p.addCurve(to: CGPoint(x: 19, y: 7), control1: CGPoint(x: 15, y: 8), control2: CGPoint(x: 17, y: 7))
        p.addCurve(to: CGPoint(x: 21, y: 12), control1: CGPoint(x: 21, y: 7), control2: CGPoint(x: 21, y: 10))
        p.addCurve(to: CGPoint(x: 12, y: 21), control1: CGPoint(x: 21, y: 17), control2: CGPoint(x: 17, y: 21))
        return p
    }

    static func sparkleFour() -> Path {
        // 4 角星（用于"AI"标识）
        var p = Path()
        let center = CGPoint(x: 12, y: 12)
        // 大十字
        p.move(to: CGPoint(x: 12, y: 3))
        p.addLine(to: CGPoint(x: 12, y: 21))
        p.move(to: CGPoint(x: 3, y: 12))
        p.addLine(to: CGPoint(x: 21, y: 12))
        // 小斜十字
        p.move(to: CGPoint(x: 6.5, y: 6.5))
        p.addLine(to: CGPoint(x: 17.5, y: 17.5))
        p.move(to: CGPoint(x: 17.5, y: 6.5))
        p.addLine(to: CGPoint(x: 6.5, y: 17.5))
        return p
    }

    static func arrowRight() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 5, y: 12))
        p.addLine(to: CGPoint(x: 19, y: 12))
        p.move(to: CGPoint(x: 12, y: 5))
        p.addLine(to: CGPoint(x: 19, y: 12))
        p.addLine(to: CGPoint(x: 12, y: 19))
        return p
    }

    static func refresh() -> Path {
        var p = Path()
        p.addArc(
            center: CGPoint(x: 12, y: 12),
            radius: 8,
            startAngle: .degrees(0),
            endAngle: .degrees(270),
            clockwise: false
        )
        p.move(to: CGPoint(x: 12, y: 4))
        p.addLine(to: CGPoint(x: 16, y: 4))
        p.addLine(to: CGPoint(x: 16, y: 8))
        return p
    }
}

// MARK: - 便捷 View 扩展

extension View {
    /// 显示指定线性图标
    func lineIcon(_ path: Path, size: CGFloat = 18, color: Color = .primary, strokeWidth: CGFloat = 1.5) -> some View {
        LineIcon(path: path, size: size, strokeWidth: strokeWidth, color: color)
    }
}

// MARK: - 图标按钮（线性图标 + 文字）

struct LineIconButton: View {
    let path: Path
    let label: String
    let action: () -> Void
    var size: CGFloat = 16

    @Environment(\.themePalette) private var palette
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                LineIcon(path: path, size: size, color: hovering ? palette.accent : palette.textSecondary)
                Text(label)
                    .font(Typography.bodyStrong)
                    .foregroundStyle(hovering ? palette.textPrimary : palette.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering ? palette.accentSoft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - 品牌 Logo（自绘）

struct BrandLogo: View {
    var size: CGFloat = 24
    var color: Color = .accentColor

    var body: some View {
        ZStack {
            // 三本书叠放的线性 logo
            ZStack {
                // 后书
                LineIcon(path: bookBack(), size: size, color: color.opacity(0.5))
                    .rotationEffect(.degrees(-15))
                    .offset(x: -size * 0.15, y: size * 0.05)
                // 前书
                LineIcon(path: bookFront(), size: size, color: color)
            }
        }
        .frame(width: size * 1.2, height: size * 1.2)
    }

    private func bookFront() -> Path {
        var p = Path()
        let s = size
        p.move(to: CGPoint(x: s * 0.3, y: s * 0.15))
        p.addLine(to: CGPoint(x: s * 0.7, y: s * 0.15))
        p.addLine(to: CGPoint(x: s * 0.7, y: s * 0.85))
        p.addLine(to: CGPoint(x: s * 0.3, y: s * 0.85))
        p.closeSubpath()
        // 书脊装饰
        p.move(to: CGPoint(x: s * 0.5, y: s * 0.15))
        p.addLine(to: CGPoint(x: s * 0.5, y: s * 0.85))
        return p
    }

    private func bookBack() -> Path {
        bookFront()  // 简化
    }
}
