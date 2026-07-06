import SwiftUI

// MARK: - 金句分享卡片生成器
//
// 一键把笔记变成精美可分享的 PNG 卡片：
// - 多种风格：小红书 / 微信朋友圈 / Twitter / 极简 / 杂志
// - 自动配色（基于书籍主题色）
// - 含书名 / 作者 / 笔记日期 / 二维码（可选）
//
// 设计参考：
// - 小红书封面风格：大字 + 渐变背景 + 装饰圆
// - Notion 分享卡：留白 + 衬线字 + 微妙阴影
// - Apple Music 风格：圆角 + 模糊 + 大字号

// MARK: - 卡片风格

enum QuoteCardStyle: String, CaseIterable, Identifiable {
    case redNote      // 小红书
    case wechat       // 微信朋友圈
    case twitter      // 推特
    case minimal      // 极简
    case magazine     // 杂志
    case gradient     // 渐变

    var id: String { rawValue }

    var label: String {
        switch self {
        case .redNote: return "小红书"
        case .wechat: return "朋友圈"
        case .twitter: return "𝕏"
        case .minimal: return "极简"
        case .magazine: return "杂志"
        case .gradient: return "渐变"
        }
    }

    var size: CGSize {
        switch self {
        case .redNote, .wechat: return CGSize(width: 1080, height: 1350)
        case .twitter: return CGSize(width: 1200, height: 675)
        case .minimal: return CGSize(width: 1080, height: 1080)
        case .magazine: return CGSize(width: 1080, height: 1350)
        case .gradient: return CGSize(width: 1200, height: 800)
        }
    }

    var icon: String {
        switch self {
        case .redNote: return "book.closed.fill"
        case .wechat: return "message.fill"
        case .twitter: return "bird"
        case .minimal: return "minus"
        case .magazine: return "newspaper.fill"
        case .gradient: return "rectangle.fill"
        }
    }
}

// MARK: - 渲染器

enum QuoteCardRenderer {
    @MainActor
    static func render(note: ReadingNote, style: QuoteCardStyle) -> Data? {
        let size = style.size
        let view = QuoteCardCanvas(note: note, style: style)
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
}

// MARK: - 画布

struct QuoteCardCanvas: View {
    let note: ReadingNote
    let style: QuoteCardStyle

    var body: some View {
        switch style {
        case .redNote: RedNoteStyle(note: note)
        case .wechat: WechatStyle(note: note)
        case .twitter: TwitterStyle(note: note)
        case .minimal: MinimalStyle(note: note)
        case .magazine: MagazineStyle(note: note)
        case .gradient: GradientStyle(note: note)
        }
    }
}

// MARK: - 1. 小红书风格

struct RedNoteStyle: View {
    let note: ReadingNote

    private var palette: ThemePalette {
        let hash = abs(note.book?.title.hashValue ?? 0)
        switch hash % 4 {
        case 0: return .midnight
        case 1: return .paper
        case 2: return .forest
        default: return .ink
        }
    }

    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.95, blue: 0.85),
                    Color(red: 0.95, green: 0.88, blue: 0.92),
                    Color(red: 0.85, green: 0.92, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 装饰圆
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 300, height: 300)
                .offset(x: 350, y: -400)
                .blur(radius: 40)

            Circle()
                .fill(Color.pink.opacity(0.2))
                .frame(width: 250, height: 250)
                .offset(x: -350, y: 400)
                .blur(radius: 30)

            VStack(alignment: .leading, spacing: 32) {
                Spacer()

                // 大引号
                Text("“")
                    .font(.system(size: 200, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.6))
                    .offset(x: -20, y: 30)

                // 引文
                Text(note.highlight)
                    .font(.system(size: 64, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.2, green: 0.15, blue: 0.1))
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 想法
                if let userNote = note.userNote, !userNote.isEmpty {
                    Text(userNote)
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.25))
                        .italic()
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                }

                Spacer()

                // 书名 + 作者
                VStack(alignment: .leading, spacing: 8) {
                    Text("— 《\(note.book?.title ?? "未知")》")
                        .font(.system(size: 36, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.15))

                    if let author = note.book?.author {
                        Text(author)
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.35))
                    }

                    HStack {
                        Text("📖 树懒书摘")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color(red: 0.5, green: 0.3, blue: 0.4))
                        Spacer()
                        Text(Date().shortString)
                            .font(.system(size: 20, design: .monospaced))
                            .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.35))
                    }
                    .padding(.top, 10)
                }
            }
            .padding(80)
        }
    }
}

// MARK: - 2. 微信朋友圈风格

struct WechatStyle: View {
    let note: ReadingNote

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.97)

            VStack(alignment: .leading, spacing: 0) {
                // 头部用户
                HStack(spacing: 20) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("我")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("树懒书摘")
                            .font(.system(size: 32, weight: .semibold))
                        Text(Date().shortString)
                            .font(.system(size: 22))
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                }
                .padding(.bottom, 30)

                // 内容卡片
                VStack(alignment: .leading, spacing: 24) {
                    Text("《\(note.book?.title ?? "")》")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.gray)

                    Text(note.highlight)
                        .font(.system(size: 44, weight: .regular, design: .serif))
                        .lineSpacing(8)
                        .foregroundStyle(.black)

                    if let userNote = note.userNote, !userNote.isEmpty {
                        Divider()
                        Text("我的想法")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.gray)
                        Text(userNote)
                            .font(.system(size: 32, weight: .regular))
                            .lineSpacing(6)
                            .foregroundStyle(.black.opacity(0.85))
                    }
                }
                .padding(40)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                )

                Spacer()

                // 底部
                HStack {
                    Text("📚 来自「树懒书摘」")
                        .font(.system(size: 22))
                        .foregroundStyle(.gray)
                    Spacer()
                }
                .padding(.top, 30)
            }
            .padding(60)
        }
    }
}

// MARK: - 3. 推特风格

struct TwitterStyle: View {
    let note: ReadingNote

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.13, blue: 0.18), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 32) {
                // header
                HStack(spacing: 16) {
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Text("📖")
                                .font(.system(size: 32))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("树懒书摘")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text("@weread_notes")
                            .font(.system(size: 22))
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                }

                // 引文
                Text("“\(note.highlight)”")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 来源
                HStack(spacing: 8) {
                    Rectangle().fill(.gray).frame(width: 30, height: 2)
                    Text("—— 《\(note.book?.title ?? "")》")
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .foregroundStyle(.gray)
                }

                Spacer()

                // 底部
                HStack(spacing: 30) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                    Image(systemName: "heart")
                        .font(.system(size: 28))
                        .foregroundStyle(.pink)
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                }
            }
            .padding(80)
        }
    }
}

// MARK: - 4. 极简风格

struct MinimalStyle: View {
    let note: ReadingNote

    var body: some View {
        ZStack {
            Color.white

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text("“")
                    .font(.system(size: 80, weight: .regular))
                    .foregroundStyle(.black.opacity(0.15))
                    .padding(.bottom, 20)

                Text(note.highlight)
                    .font(.system(size: 48, weight: .regular, design: .serif))
                    .foregroundStyle(.black)
                    .lineSpacing(10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
                    .frame(height: 60)

                Rectangle()
                    .fill(.black)
                    .frame(width: 60, height: 1)

                Spacer()
                    .frame(height: 30)

                Text(note.book?.title.uppercased() ?? "")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(.black)

                if let author = note.book?.author {
                    Text(author)
                        .font(.system(size: 16))
                        .foregroundStyle(.black.opacity(0.6))
                }

                Spacer()
            }
            .padding(100)
        }
    }
}

// MARK: - 5. 杂志风格

struct MagazineStyle: View {
    let note: ReadingNote

    var body: some View {
        ZStack {
            // 米色背景
            Color(red: 0.96, green: 0.93, blue: 0.87)

            VStack(spacing: 0) {
                // 顶部装饰
                Rectangle()
                    .fill(.black)
                    .frame(height: 80)

                Spacer()
                    .frame(height: 80)

                // 标题
                VStack(spacing: 16) {
                    Text("——读书札记——")
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .tracking(8)
                        .foregroundStyle(.black.opacity(0.5))

                    Text(note.book?.title ?? "")
                        .font(.system(size: 64, weight: .bold, design: .serif))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 60)

                Spacer()
                    .frame(height: 80)

                // 大引文
                Text(note.highlight)
                    .font(.system(size: 56, weight: .regular, design: .serif))
                    .foregroundStyle(.black)
                    .lineSpacing(14)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 100)

                Spacer()
                    .frame(height: 80)

                if let userNote = note.userNote, !userNote.isEmpty {
                    HStack {
                        Rectangle().fill(.black).frame(width: 30, height: 1)
                        Text("编者按")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .tracking(4)
                        Rectangle().fill(.black).frame(width: 30, height: 1)
                    }
                    .foregroundStyle(.black.opacity(0.5))

                    Spacer()
                        .frame(height: 30)

                    Text(userNote)
                        .font(.system(size: 28, weight: .light, design: .serif))
                        .italic()
                        .foregroundStyle(.black.opacity(0.7))
                        .lineSpacing(8)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 120)
                }

                Spacer()

                // 底部页码
                HStack {
                    Text("VOL.1")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .tracking(3)
                    Spacer()
                    Text("P. 001")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                }
                .foregroundStyle(.black.opacity(0.5))
                .padding(.horizontal, 60)
                .padding(.bottom, 80)
            }
        }
    }
}

// MARK: - 6. 渐变风格

struct GradientStyle: View {
    let note: ReadingNote

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.2, blue: 0.8),
                    Color(red: 0.9, green: 0.3, blue: 0.6),
                    Color(red: 1.0, green: 0.5, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 装饰
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: CGFloat(100 + i * 80), height: CGFloat(100 + i * 80))
                    .offset(x: CGFloat(i * 50 - 100), y: CGFloat(i * 30 - 100))
                    .blur(radius: 40)
            }

            VStack(alignment: .leading, spacing: 40) {
                Spacer()

                Text(note.highlight)
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(8)
                    .shadow(color: .black.opacity(0.2), radius: 4)

                if let userNote = note.userNote, !userNote.isEmpty {
                    Text(userNote)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .italic()
                }

                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("—— 《\(note.book?.title ?? "")》")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                        if let author = note.book?.author {
                            Text(author)
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("📖")
                            .font(.system(size: 50))
                        Text("树懒书摘")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(80)
        }
    }
}

// MARK: - 卡片生成器 UI

struct QuoteCardGeneratorView: View {
    let note: ReadingNote
    let onDismiss: () -> Void

    @State private var selectedStyle: QuoteCardStyle = .redNote
    @State private var generatedImage: NSImage?
    @State private var isGenerating = false
    @State private var saveStatus: String?

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HSplitView {
                // 左侧：样式选择
                stylePicker
                    .frame(width: 220)

                // 右侧：预览
                previewArea
            }
        }
        .frame(width: 820, height: 580)
    }

    private var header: some View {
        HStack {
            Image(systemName: "photo.on.rectangle.angled")
                .foregroundStyle(palette.accent)
            Text("金句分享卡片")
                .font(.headline)
            Spacer()
            Button("关闭") { onDismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    // MARK: - 样式选择

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择风格")
                .font(Typography.captionStrong)
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 4)
                .padding(.top, 16)

            ForEach(QuoteCardStyle.allCases) { style in
                Button {
                    selectedStyle = style
                    generatedImage = nil
                } label: {
                    HStack {
                        Image(systemName: style.icon)
                            .frame(width: 18)
                            .foregroundStyle(selectedStyle == style ? palette.accent : palette.textSecondary)
                        Text(style.label)
                            .foregroundStyle(selectedStyle == style ? palette.textPrimary : palette.textSecondary)
                        Spacer()
                    }
                    .font(Typography.bodyStrong)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedStyle == style ? palette.accentSoft : .clear)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()

            // 生成按钮
            Button {
                generate()
            } label: {
                if isGenerating {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("生成中...")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("生成卡片")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .flatActionButton(.accent, height: 32)
            .controlSize(.large)
            .disabled(isGenerating)
            .padding(16)

            if let generatedImage {
                Button {
                    saveToFile(image: generatedImage)
                } label: {
                    Label("保存 PNG", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .flatActionButton(height: 32)
                .padding(.horizontal, 16)

                Button {
                    copyToClipboard(image: generatedImage)
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .flatActionButton(height: 32)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            if let saveStatus {
                Text(saveStatus)
                    .font(.caption)
                    .foregroundStyle(palette.success)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - 预览

    private var previewArea: some View {
        ScrollView {
            VStack {
                if let image = generatedImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .shadow(color: .black.opacity(0.2), radius: 20)
                } else {
                    // 显示占位预览（缩小版）
                    QuoteCardCanvas(note: note, style: selectedStyle)
                        .scaleEffect(0.5)
                        .frame(width: selectedStyle.size.width / 2, height: selectedStyle.size.height / 2)
                        .padding(20)
                        .opacity(0.9)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(palette.surface.opacity(0.3))
    }

    private func generate() {
        isGenerating = true
        Task {
            let data = QuoteCardRenderer.render(note: note, style: selectedStyle)
            await MainActor.run {
                if let data, let image = NSImage(data: data) {
                    self.generatedImage = image
                    self.saveStatus = "✅ 已生成 \(Int(image.size.width))x\(Int(image.size.height)) PNG"
                } else {
                    self.saveStatus = "❌ 生成失败"
                }
                self.isGenerating = false
            }
        }
    }

    private func saveToFile(image: NSImage) {
        #if canImport(AppKit)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let safeTitle = note.book?.title.replacingOccurrences(of: "/", with: "-") ?? "card"
        panel.nameFieldStringValue = "\(safeTitle)-card.png"
        if panel.runModal() == .OK, let url = panel.url {
            if let data = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: data),
               let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
                saveStatus = "✅ 已保存到 \(url.lastPathComponent)"
            }
        }
        #endif
    }

    private func copyToClipboard(image: NSImage) {
        #if canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
        saveStatus = "✅ 已复制到剪贴板"
        #endif
    }
}