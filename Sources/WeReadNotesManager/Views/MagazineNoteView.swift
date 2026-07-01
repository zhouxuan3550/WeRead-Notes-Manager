import SwiftUI

// MARK: - 杂志式笔记详情
//
// 设计参考 iA Writer / Medium：
// - 内容居中 680px
// - 衬线字体 + 大行距
// - 段首缩进 / 引文特殊样式
// - 顶部 hero 模糊背景 = 书籍封面

struct MagazineNoteView: View {
    let note: ReadingNote
    @Binding var fontSize: CGFloat
    @Binding var fontFamily: MagazineFont

    @Environment(\.themePalette) private var palette

    enum MagazineFont: String, CaseIterable, Identifiable {
        case serif = "宋体"
        case sans = "黑体"
        case mono = "等宽"

        var id: String { rawValue }

        func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            switch self {
            case .serif: return .system(size: size, weight: weight, design: .serif)
            case .sans: return .system(size: size, weight: weight, design: .default)
            case .mono: return .system(size: size, weight: weight, design: .monospaced)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                articleContent
                    .padding(.horizontal, 60)
                    .padding(.bottom, 80)
            }
        }
        .background(palette.background)
    }

    // MARK: - Hero（书籍封面模糊背景）

    private var hero: some View {
        ZStack {
            // 封面作为模糊背景
            if let urlString = note.book?.coverURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 50)
                            .opacity(0.35)
                    } else {
                        Color.clear
                    }
                }
            } else {
                LinearGradient(
                    colors: [
                        palette.accent.opacity(0.20),
                        palette.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // 顶部渐变蒙板
            LinearGradient(
                colors: [palette.background.opacity(0), palette.background],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 16) {
                if let book = note.book {
                    BookCoverView(book: book, size: .large)
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                }

                VStack(spacing: 8) {
                    Text(note.book?.title ?? "未关联书籍")
                        .font(fontFamily.font(size: 28, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                    if let author = note.book?.author {
                        Text(author)
                            .font(fontFamily.font(size: 14))
                            .foregroundStyle(palette.textSecondary)
                    }
                    if let chapter = note.chapter {
                        Text("· \(chapter) ·")
                            .font(fontFamily.font(size: 13))
                            .foregroundStyle(palette.textTertiary)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
        .frame(height: 360)
        .clipped()
    }

    // MARK: - 正文

    private var articleContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 原文（引文样式）
            VStack(alignment: .leading, spacing: 12) {
                Label("原文", systemImage: "quote.opening")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                    .textCase(.uppercase)

                Text(note.highlight)
                    .font(fontFamily.font(size: fontSize + 3, weight: .regular))
                    .lineSpacing((fontSize + 3) * 0.55)
                    .foregroundStyle(palette.textPrimary)
                    .padding(.leading, 16)
                    .overlay(
                        Rectangle()
                            .fill(palette.accent)
                            .frame(width: 3)
                            .padding(.vertical, 4),
                        alignment: .leading
                    )
            }

            // 分隔花絮
            HStack(spacing: 8) {
                Rectangle().fill(palette.borderSubtle).frame(height: 1)
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textTertiary)
                Rectangle().fill(palette.borderSubtle).frame(height: 1)
            }
            .padding(.vertical, 8)

            // 想法
            if let userNote = note.userNote, !userNote.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Label("我的想法", systemImage: "lightbulb")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                        .textCase(.uppercase)

                    Text(userNote)
                        .font(fontFamily.font(size: fontSize, weight: .regular))
                        .lineSpacing(fontSize * 0.55)
                        .foregroundStyle(palette.textPrimary.opacity(0.92))
                        .textSelection(.enabled)
                }
            }

            // 元信息脚注
            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(palette.borderSubtle).frame(height: 1)
                HStack(spacing: 16) {
                    if let createdAt = note.createdAt {
                        metaFootnote(icon: "calendar", text: createdAt.shortString)
                    }
                    metaFootnote(icon: "tag", text: "复习 \(note.reviewCount) 次")
                    if note.isFavorite {
                        metaFootnote(icon: "star.fill", text: "已收藏")
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private func metaFootnote(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundStyle(palette.textTertiary)
    }
}

// MARK: - 阅读控制面板（字号 + 字体切换）

struct ReadingControlBar: View {
    @Binding var fontSize: CGFloat
    @Binding var fontFamily: MagazineNoteView.MagazineFont

    @Environment(\.themePalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Button { fontSize = max(14, fontSize - 1) } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                Text("\(Int(fontSize))pt")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(width: 32)
                Button { fontSize = min(24, fontSize + 1) } label: {
                    Image(systemName: "textformat.size.larger")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(palette.surface))
            .foregroundStyle(palette.textPrimary)

            Picker("字体", selection: $fontFamily) {
                ForEach(MagazineNoteView.MagazineFont.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        )
    }
}