import AppKit
import SwiftUI

struct ReadingCardView: View {
    let note: ReadingNote
    let template: ReadingCardTemplate

    init(note: ReadingNote, template: ReadingCardTemplate = .dark) {
        self.note = note
        self.template = template
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 14) {
                if let book = note.book {
                    BookCoverView(book: book, size: .medium)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(template.primaryColor)
                            .lineLimit(2)
                        Text(book.author ?? "未知作者")
                            .font(.system(size: 13))
                            .foregroundStyle(template.secondaryColor)
                    }
                }
                Spacer()
                Text("树懒书摘")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(template.secondaryColor)
            }

            Text(note.highlight)
                .font(.system(size: 28, weight: .semibold))
                .lineSpacing(8)
                .foregroundStyle(template.primaryColor)
                .minimumScaleFactor(0.72)

            if let userNote = note.userNote, !userNote.isEmpty {
                Text(userNote)
                    .font(.system(size: 17))
                    .lineSpacing(5)
                    .foregroundStyle(template.secondaryColor)
                    .padding(.top, 4)
            }

            Spacer()

            HStack {
                Text(note.chapter ?? "微信读书笔记")
                    .font(.system(size: 13))
                    .foregroundStyle(template.secondaryColor)
                    .lineLimit(1)
                Spacer()
                if let createdAt = note.createdAt {
                    Text(createdAt.shortString)
                        .font(.system(size: 13))
                        .foregroundStyle(template.secondaryColor)
                }
            }
        }
        .padding(34)
        .frame(width: 900, height: 1200)
        .background(
            ZStack {
                template.background
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(template.accentColor.opacity(0.32))
                        .frame(height: 8)
                }
            }
        )
    }
}

enum ReadingCardTemplate: String, CaseIterable, Identifiable {
    case dark
    case paper
    case minimal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dark: return "深色"
        case .paper: return "纸张"
        case .minimal: return "极简"
        }
    }

    var primaryColor: Color {
        switch self {
        case .dark: return .white
        case .paper, .minimal: return Color(red: 0.12, green: 0.12, blue: 0.10)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .dark: return .white.opacity(0.68)
        case .paper, .minimal: return Color(red: 0.33, green: 0.31, blue: 0.27)
        }
    }

    var accentColor: Color {
        switch self {
        case .dark: return Color(red: 0.72, green: 0.50, blue: 0.22)
        case .paper: return Color(red: 0.65, green: 0.35, blue: 0.22)
        case .minimal: return .black
        }
    }

    var background: some View {
        switch self {
        case .dark:
            return AnyView(LinearGradient(
                colors: [Color(red: 0.10, green: 0.13, blue: 0.12), Color(red: 0.03, green: 0.04, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .paper:
            return AnyView(Color(red: 0.94, green: 0.89, blue: 0.79))
        case .minimal:
            return AnyView(Color(red: 0.97, green: 0.97, blue: 0.95))
        }
    }
}

enum ReadingCardExporter {
    @MainActor
    static func export(note: ReadingNote, template: ReadingCardTemplate = .dark) throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(note.book?.title ?? "reading-note")-card.png"
        panel.prompt = "保存卡片"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let renderer = ImageRenderer(content: ReadingCardView(note: note, template: template))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ReadingCardExportError.renderFailed
        }

        try pngData.write(to: url)
    }

    @MainActor
    static func exportBatch(notes: [ReadingNote], template: ReadingCardTemplate = .dark) throws {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择文件夹"

        guard panel.runModal() == .OK, let directory = panel.url else {
            return
        }

        for (index, note) in notes.enumerated() {
            let renderer = ImageRenderer(content: ReadingCardView(note: note, template: template))
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw ReadingCardExportError.renderFailed
            }
            let fileName = "\(String(format: "%02d", index + 1))-\(safeFileName(note.book?.title ?? "reading-note")).png"
            try pngData.write(to: directory.appendingPathComponent(fileName))
        }
    }

    private static func safeFileName(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }
}

enum ReadingCardExportError: LocalizedError {
    case renderFailed

    var errorDescription: String? {
        "生成读书卡片失败。"
    }
}
