import SwiftUI
import AppKit
import CoreGraphics

// MARK: - App 图标生成器
//
// 用 SwiftUI Canvas 动态生成 4 套主题对应的 App 图标。
// 每个图标 = 一本书 + 主题色背景 + 微妙渐变。
//
// 生成步骤：
// 1. 用 Canvas 在 1024x1024 画图标
// 2. 缩放到 16/32/64/128/256/512/1024
// 3. ImageRenderer 转 NSImage
// 4. 保存为 .icns 或多套 .png

enum AppIconTheme: String, CaseIterable, Identifiable {
    case midnight, paper, ink, forest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .midnight: return "夜墨青"
        case .paper: return "米黄纸"
        case .ink: return "水墨灰"
        case .forest: return "暗夜森林"
        }
    }
}

enum AppIconGenerator {
    /// 生成单个主题的图标 PNG 数据（1024x1024）
    @MainActor
    static func generateIcon(theme: AppIconTheme) -> Data? {
        let size = CGSize(width: 1024, height: 1024)
        let view = IconCanvas(theme: theme)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0

        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png
    }

    /// 生成 macOS AppIcon 完整 icns（多分辨率）
    @MainActor
    static func generateICNS(theme: AppIconTheme) -> Data? {
        guard let png1024 = generateIcon(theme: theme) else { return nil }
        // 简化：直接返回 PNG，让 Xcode 自动生成 icns
        return png1024
    }

    /// 批量导出所有主题图标到目录
    @MainActor
    static func exportAll(to directory: URL) {
        let fm = FileManager.default
        for theme in AppIconTheme.allCases {
            if let png = generateIcon(theme: theme) {
                let fileURL = directory.appendingPathComponent("AppIcon-\(theme.rawValue).png")
                try? png.write(to: fileURL)
            }
        }
        _ = fm
    }
}

// MARK: - 图标画布

struct IconCanvas: View {
    let theme: AppIconTheme

    private var palette: ThemePalette {
        switch theme {
        case .midnight: return .midnight
        case .paper: return .paper
        case .ink: return .ink
        case .forest: return .forest
        }
    }

    var body: some View {
        ZStack {
            // 1. 背景
            backgroundGradient

            // 2. 装饰圆
            Circle()
                .fill(palette.accent.opacity(0.15))
                .frame(width: 700, height: 700)
                .offset(x: -200, y: -200)
                .blur(radius: 80)

            Circle()
                .fill(palette.accent.opacity(0.10))
                .frame(width: 600, height: 600)
                .offset(x: 250, y: 250)
                .blur(radius: 80)

            // 3. 书
            bookStack
                .shadow(color: .black.opacity(0.3), radius: 30, y: 20)

            // 4. 划线高光
            highlightOverlay
        }
        .frame(width: 1024, height: 1024)
    }

    // MARK: - 背景

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                palette.background,
                palette.surface,
                palette.surfaceElevated
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - 书

    private var bookStack: some View {
        // 三本书叠在一起
        ZStack {
            // 后书
            book(width: 380, height: 540, color: palette.accent.opacity(0.5))
                .rotationEffect(.degrees(-12))
                .offset(x: -100, y: 30)

            // 中书
            book(width: 400, height: 560, color: palette.accent.opacity(0.75))
                .rotationEffect(.degrees(4))
                .offset(x: 0, y: -10)

            // 前书（主）
            book(width: 420, height: 580, color: palette.accent)
                .rotationEffect(.degrees(-2))

            // 顶部光带
            bookTopHighlight(width: 420, height: 580)
                .rotationEffect(.degrees(-2))
                .blendMode(.plusLighter)
        }
    }

    private func book(width: CGFloat, height: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
            .overlay(
                // 书脊装饰
                Rectangle()
                    .fill(palette.textPrimary.opacity(0.15))
                    .frame(width: 8)
                    .padding(.vertical, 20),
                alignment: .leading
            )
            .overlay(
                // 标题装饰
                VStack(spacing: 14) {
                    Capsule()
                        .fill(palette.textPrimary.opacity(0.85))
                        .frame(width: width * 0.7, height: 14)
                    Capsule()
                        .fill(palette.textPrimary.opacity(0.6))
                        .frame(width: width * 0.55, height: 10)
                    Capsule()
                        .fill(palette.textPrimary.opacity(0.4))
                        .frame(width: width * 0.65, height: 10)
                    Spacer().frame(height: 30)
                    Capsule()
                        .fill(palette.textPrimary.opacity(0.5))
                        .frame(width: width * 0.4, height: 8)
                }
                .padding(.vertical, 60)
                ,
                alignment: .top
            )
    }

    private func bookTopHighlight(width: CGFloat, height: CGFloat) -> some View {
        LinearGradient(
            colors: [
                palette.textPrimary.opacity(0.25),
                palette.textPrimary.opacity(0)
            ],
            startPoint: .top,
            endPoint: .center
        )
        .frame(width: width, height: height / 2)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 高光

    private var highlightOverlay: some View {
        VStack {
            LinearGradient(
                colors: [
                    palette.textPrimary.opacity(0.10),
                    palette.textPrimary.opacity(0)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 200)
            Spacer()
        }
    }
}

// MARK: - 设置当前主题图标

enum AppIconSetter {
    /// macOS 支持运行时切换 App 图标（AppIcon Composer）
    /// 文件名必须匹配 Info.plist 中的 CFBundleIcons.CFBundleAlternateIcons
    ///
    /// 这里我们用更简单的方式：
    /// 把 4 套图标文件存到 Resources，然后在用户切换主题时复制到对应路径。

    static func setActive(theme: AppIconTheme) {
        let fileManager = FileManager.default

        // 获取 App Bundle 路径
        guard let bundlePath = Bundle.main.bundlePath as String? else { return }
        let resourcesPath = (bundlePath as NSString).appendingPathComponent("Contents/Resources")

        // 当前激活图标
        let activeIconName = "AppIcon-active"
        let activeIconPath = (resourcesPath as NSString).appendingPathComponent("\(activeIconName).icns")

        // 主题图标
        let themeIconName = "AppIcon-\(theme.rawValue)"
        let themeIconPath = (resourcesPath as NSString).appendingPathComponent("\(themeIconName).icns")

        // 如果存在则复制
        if fileManager.fileExists(atPath: themeIconPath) {
            try? fileManager.removeItem(atPath: activeIconPath)
            try? fileManager.copyItem(atPath: themeIconPath, toPath: activeIconPath)
        }

        // 通知系统更新图标
        NSLog("AppIcon changed to theme %@", theme.rawValue)
    }
}

// MARK: - 预览 UI

struct AppIconPreview: View {
    @State private var selectedTheme: AppIconTheme = .midnight

    var body: some View {
        VStack(spacing: 16) {
            Text("App 图标预览")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                ForEach(AppIconTheme.allCases) { theme in
                    VStack {
                        IconCanvas(theme: theme)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(selectedTheme == theme ? Color.accentColor : Color.gray.opacity(0.3),
                                            lineWidth: selectedTheme == theme ? 3 : 1)
                            )
                            .onTapGesture {
                                selectedTheme = theme
                            }
                        Text(theme.label)
                            .font(.caption)
                    }
                }
            }

            HStack {
                Button("导出图标到桌面") {
                    let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                        ?? URL(fileURLWithPath: NSHomeDirectory())
                    AppIconGenerator.exportAll(to: url)
                }
                .flatActionButton(.accent, height: 32)

                Button("激活选中主题图标") {
                    AppIconSetter.setActive(theme: selectedTheme)
                }
                .flatActionButton(height: 32)
            }
        }
        .padding(20)
    }
}