import SwiftUI
import SwiftData
import AppKit

/// 分享卡片工厂：选择模板、实时预览、导出 PNG/复制图片。
struct ShareCardStudioView: View {
    var note: ReadingNote?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themePalette) private var palette
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]

    @State private var selectedNote: ReadingNote?
    @State private var selectedTemplateID = BuiltInShareCardTemplates.all.first?.id ?? "minimal"
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 260)
                Divider()
                previewPanel
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("卡片工厂")
                    .font(.system(size: 18, weight: .semibold))
                Text("把书摘生成可分享的精美图片")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if note == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择书摘")
                            .font(.system(size: 13, weight: .semibold))
                        Picker("", selection: $selectedNote) {
                            Text("请选择").tag(ReadingNote?.none)
                            ForEach(allNotes) { note in
                                Text(shortTitle(for: note))
                                    .tag(note as ReadingNote?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("选择模板")
                        .font(.system(size: 13, weight: .semibold))

                    ForEach(BuiltInShareCardTemplates.all, id: \.id) { template in
                        Button {
                            selectedTemplateID = template.id
                        } label: {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(template.id == selectedTemplateID ? palette.accent : palette.surfaceElevated)
                                    .frame(width: 8, height: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text(template.id)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if template.id == selectedTemplateID {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11))
                                        .foregroundStyle(palette.accent)
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(template.id == selectedTemplateID ? palette.accent.opacity(0.08) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(template.id == selectedTemplateID ? palette.accent.opacity(0.3) : palette.borderSubtle, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    private var previewPanel: some View {
        VStack(spacing: 16) {
            if let currentNote = selectedNote ?? note {
                let template = BuiltInShareCardTemplates.template(id: selectedTemplateID)
                let data = ShareCardData(
                    highlight: currentNote.highlight,
                    bookTitle: currentNote.book?.title ?? "未知书籍",
                    author: currentNote.book?.author,
                    userNote: currentNote.userNote,
                    themeColor: palette.accent
                )

                VStack(spacing: 0) {
                    template.body(for: data)
                        .scaleEffect(0.55)
                        .frame(width: 700 * 0.55, height: 420 * 0.55)
                }
                .background(Color.gray.opacity(0.08))
                .cornerRadius(12)

                HStack(spacing: 12) {
                    Button {
                        exportPNG(note: currentNote, template: template)
                    } label: {
                        Label("导出 PNG", systemImage: "photo")
                    }
                    .flatActionButton(.accent, height: 32)

                    Button {
                        copyImage(note: currentNote, template: template)
                    } label: {
                        Label("复制图片", systemImage: "doc.on.doc")
                    }
                    .flatActionButton(.secondary, height: 32)
                }
            } else {
                ContentUnavailableView(
                    "选择一条书摘",
                    systemImage: "photo.artframe",
                    description: Text("在左侧选择书摘和模板")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
    }

    private var allNotes: [ReadingNote] {
        books.flatMap { $0.notes }.filter { !$0.isDeleted }
    }

    private func shortTitle(for note: ReadingNote) -> String {
        let text = note.highlight.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > 24 { return String(text.prefix(24)) + "..." }
        return text
    }

    private func cardData(for note: ReadingNote) -> ShareCardData {
        ShareCardData(
            highlight: note.highlight,
            bookTitle: note.book?.title ?? "未知书籍",
            author: note.book?.author,
            userNote: note.userNote,
            themeColor: palette.accent
        )
    }

    private func renderView(for note: ReadingNote, template: ShareCardTemplate) -> some View {
        template.body(for: cardData(for: note))
    }

    private func exportPNG(note: ReadingNote, template: ShareCardTemplate) {
        let view = renderView(for: note, template: template)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0

        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            statusMessage = "图片渲染失败"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "share-card-\(note.id.uuidString.prefix(8)).png"
        if panel.runModal() == .OK, let url = panel.url {
            try? png.write(to: url)
            statusMessage = "已导出：\(url.lastPathComponent)"
        }
    }

    private func copyImage(note: ReadingNote, template: ShareCardTemplate) {
        let view = renderView(for: note, template: template)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0

        guard let nsImage = renderer.nsImage else {
            statusMessage = "图片渲染失败"
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([nsImage])
        statusMessage = "已复制到剪贴板"
    }
}
