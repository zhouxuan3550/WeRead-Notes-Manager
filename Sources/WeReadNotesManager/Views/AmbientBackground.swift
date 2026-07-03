import SwiftUI

// MARK: - 背景氛围
//
// 用 Canvas 实时渲染：
// 1. 渐变底色（主题色混合）
// 2. 角落光晕（4 个角各一团柔光）
// 3. 噪点纹理（覆盖整个画布）
// 4. 可选：网格点 / 微 Logo
//
// 比 SwiftUI 静态背景多 100 倍质感。

// MARK: - 噪点纹理生成器

enum NoiseTexture {
    /// 生成噪点纹理（CGImage）
    static func generate(size: CGSize = CGSize(width: 200, height: 200), intensity: CGFloat = 0.05) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        for i in 0..<width * height {
            let random = UInt8.random(in: 0...255)
            let alpha = UInt8(min(255, Double(random) * intensity * 4))
            pixelData[i * 4 + 0] = 255
            pixelData[i * 4 + 1] = 255
            pixelData[i * 4 + 2] = 255
            pixelData[i * 4 + 3] = alpha
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        return context.makeImage()
    }
}

// MARK: - 噪点纹理 View

struct NoiseOverlay: View {
    var intensity: CGFloat = 0.04
    var blendMode: BlendMode = .overlay

    @State private var noiseImage: CGImage?

    var body: some View {
        Group {
            if let noiseImage {
                Image(noiseImage, scale: 1.0, label: Text(""))
                    .resizable()
                    .scaledToFill()
                    .opacity(intensity * 8)  // 因为是 overlay 模式，需要乘以 8 才看得到
                    .blendMode(blendMode)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            if noiseImage == nil {
                noiseImage = NoiseTexture.generate(intensity: intensity)
            }
        }
    }
}

// MARK: - 角落光晕

struct CornerGlows: View {
    @Environment(\.themePalette) private var palette
    var corners: [Corner] = [.topLeading, .bottomTrailing]
    var radius: CGFloat = 380
    var intensity: CGFloat = 0.18

    enum Corner {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
    }

    var body: some View {
        Canvas { ctx, size in
            for corner in corners {
                let center = centerPoint(for: corner, in: size)
                let gradient = Gradient(stops: [
                    .init(color: palette.accent.opacity(intensity), location: 0),
                    .init(color: palette.accent.opacity(0), location: 1)
                ])
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        gradient,
                        center: center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
        .ignoresSafeArea()
        .blendMode(.plusLighter)
    }

    private func centerPoint(for corner: Corner, in size: CGSize) -> CGPoint {
        switch corner {
        case .topLeading: return CGPoint(x: 0, y: 0)
        case .topTrailing: return CGPoint(x: size.width, y: 0)
        case .bottomLeading: return CGPoint(x: 0, y: size.height)
        case .bottomTrailing: return CGPoint(x: size.width, y: size.height)
        }
    }
}

// MARK: - 装饰性网格点

struct DotGrid: View {
    @Environment(\.themePalette) private var palette
    var spacing: CGFloat = 32
    var dotSize: CGFloat = 1.5
    var opacity: CGFloat = 0.15

    var body: some View {
        Canvas { ctx, size in
            let cols = Int(size.width / spacing)
            let rows = Int(size.height / spacing)

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing + spacing / 2
                    let y = CGFloat(row) * spacing + spacing / 2
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .color(palette.textPrimary.opacity(opacity))
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 完整氛围背景

struct AmbientBackground: View {
    var showGlows: Bool = true
    var showNoise: Bool = true
    var showDots: Bool = false

    @Environment(\.themePalette) private var palette

    var body: some View {
        ZStack {
            palette.background

            if showGlows {
                CornerGlows(corners: [.topTrailing], radius: 420, intensity: 0.035)
            }

            if showDots {
                DotGrid(spacing: 40, dotSize: 1.0, opacity: 0.06)
            }

            if showNoise {
                NoiseOverlay(intensity: 0.010, blendMode: .softLight)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 玻璃面板（升级版）

struct GlassPanelV2: View {
    @Environment(\.themePalette) private var palette
    var cornerRadius: CGFloat = 16
    var elevation: GlassPanelV2.Elevation = .medium
    var borderColor: Color? = nil

    enum Elevation {
        case low, medium, high

        var shadowOpacity: Double {
            switch self {
            case .low: return 0.08
            case .medium: return 0.15
            case .high: return 0.22
            }
        }

        var shadowRadius: CGFloat {
            switch self {
            case .low: return 8
            case .medium: return 16
            case .high: return 28
            }
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(palette.surfaceElevated.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor ?? palette.borderSubtle, lineWidth: 0.8)
            )
    }
}

// MARK: - 渐变卡片（侧栏/仪表盘背景）

struct GradientSurface: View {
    @Environment(\.themePalette) private var palette
    var cornerRadius: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.surface,
                        palette.surfaceElevated,
                        palette.surface.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                LinearGradient(
                    colors: [
                        palette.accent.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - 顶部装饰光带

struct TopLightBand: View {
    @Environment(\.themePalette) private var palette
    var height: CGFloat = 180

    var body: some View {
        VStack {
            LinearGradient(
                colors: [
                    palette.accent.opacity(0.10),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .ignoresSafeArea()
            Spacer()
        }
    }
}

// MARK: - 视图扩展

extension View {
    /// 应用氛围背景
    func ambientBackground(
        glows: Bool = true,
        noise: Bool = true,
        dots: Bool = false
    ) -> some View {
        background(
            AmbientBackground(
                showGlows: glows,
                showNoise: noise,
                showDots: dots
            )
        )
    }

    /// 玻璃面板修饰
    func glassV2(cornerRadius: CGFloat = 16, elevation: GlassPanelV2.Elevation = .medium) -> some View {
        background(
            GlassPanelV2(cornerRadius: cornerRadius, elevation: elevation)
        )
    }

    /// 渐变表面
    func gradientSurface(cornerRadius: CGFloat = 16) -> some View {
        background(
            GradientSurface(cornerRadius: cornerRadius)
        )
    }
}
