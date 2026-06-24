import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var exportScope: ExportScope = .all
    @State private var exportFormat: ExportFormat = .pdf
    @State private var template: NoteTemplate = .readingReport
    @State private var exportPackage = ExportPackage(data: Data(), contentType: .data, filename: "weread-notes")
    @State private var isExporting = false
    @State private var exportSuccess = false
    @State private var exportError: String?

    @AppStorage("customNoteExportTemplate") private var customTemplate = """
    > {{quote}}

    我的想法：
    {{thought}}

    {{book}} · {{chapter}} · {{location}}
    """

    var body: some View {
        HStack(spacing: 0) {
            controlPanel
                .frame(width: 300)

            Divider()

            previewPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 780, minHeight: 560)
        .background(AppBackdrop())
        .fileExporter(
            isPresented: $isExporting,
            document: BinaryExportDocument(data: exportPackage.data, type: exportPackage.contentType),
            contentType: exportPackage.contentType,
            defaultFilename: exportPackage.filename
        ) { result in
            switch result {
            case .success:
                exportSuccess = true
            case .failure(let error):
                exportError = error.localizedDescription
            }
        }
        .alert("导出成功", isPresented: $exportSuccess) {
            Button("好") { dismiss() }
        }
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("好") {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("导出中心")
                        .font(.system(size: 24, weight: .bold))
                    Text("选择范围、格式和模板")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }

            GroupBox("范围") {
                VStack(spacing: 8) {
                    ForEach(availableScopes) { scope in
                        optionRow(
                            title: scope.title,
                            subtitle: scope.subtitle,
                            icon: scope.systemImage,
                            isSelected: exportScope == scope
                        ) {
                            exportScope = scope
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("格式") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(ExportFormat.allCases) { format in
                        formatButton(format)
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("模板") {
                VStack(spacing: 8) {
                    ForEach(NoteTemplate.allCases) { item in
                        optionRow(
                            title: item.title,
                            subtitle: item.subtitle,
                            icon: item == .custom ? "slider.horizontal.3" : "doc.text.magnifyingglass",
                            isSelected: template == item
                        ) {
                            template = item
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            Button {
                prepareExport()
            } label: {
                Label("导出 \(exportFormat.title)", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(notesToExport.isEmpty)
        }
        .padding(22)
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(previewTitle)
                        .font(.system(size: 22, weight: .bold))
                    Text("\(notesToExport.count) 条笔记 · \(bookCount) 本书 · \(exportFormat.title)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label(template.title, systemImage: "wand.and.stars")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(.thinMaterial))
            }

            if template == .custom {
                customTemplateEditor
            } else {
                previewCard
            }

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private var customTemplateEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自定义模板")
                .font(.system(size: 15, weight: .semibold))
            TextEditor(text: $customTemplate)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.16)))
                .frame(minHeight: 180)

            Text("可用占位符：{{book}} {{author}} {{chapter}} {{quote}} {{thought}} {{location}} {{date}} {{favorite}} {{reviewCount}}")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            previewCard
        }
    }

    private var previewCard: some View {
        ScrollView {
            Text(previewText)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(18)
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.16)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.08)))
    }

    private func formatButton(_ format: ExportFormat) -> some View {
        Button {
            exportFormat = format
        } label: {
            VStack(spacing: 6) {
                Image(systemName: format.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(format.title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 8).fill(exportFormat == format ? Color.accentColor.opacity(0.26) : Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(exportFormat == format ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private func optionRow(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.white.opacity(0.09) : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private func prepareExport() {
        do {
            let builder = ExportDocumentBuilder(
                notes: notesToExport,
                format: exportFormat,
                template: template,
                customTemplate: customTemplate,
                baseFilename: baseFilename
            )
            exportPackage = try builder.build()
            isExporting = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var availableScopes: [ExportScope] {
        var scopes: [ExportScope] = [.all, .favorites, .unreviewed]
        if appVM.selectedBook != nil {
            scopes.append(.currentBook)
        }
        return scopes
    }

    private var notesToExport: [ReadingNote] {
        switch exportScope {
        case .favorites:
            return appVM.allNotes.filter { $0.isFavorite }
        case .unreviewed:
            return appVM.allNotes.filter { !$0.isReviewed }
        case .currentBook:
            return appVM.selectedBook?.notes ?? []
        case .all:
            return appVM.allNotes
        }
    }

    private var bookCount: Int {
        Set(notesToExport.compactMap { $0.book?.id }).count
    }

    private var previewTitle: String {
        switch exportScope {
        case .all: return "全部书摘"
        case .favorites: return "收藏书摘"
        case .unreviewed: return "待复习书摘"
        case .currentBook: return appVM.selectedBook?.title ?? "当前书籍"
        }
    }

    private var previewText: String {
        let sampleNotes = Array(notesToExport.prefix(8))
        guard !sampleNotes.isEmpty else {
            return "暂无可导出的笔记。"
        }
        return ExportDocumentBuilder(
            notes: sampleNotes,
            format: exportFormat == .obsidian ? .markdown : exportFormat,
            template: template,
            customTemplate: customTemplate,
            baseFilename: baseFilename
        )
        .renderPreview()
    }

    private var baseFilename: String {
        let scope = previewTitle
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "\(scope)-\(DateFormatter.fileDayStamp.string(from: Date()))"
    }
}

private enum ExportScope: String, CaseIterable, Identifiable {
    case all
    case favorites
    case unreviewed
    case currentBook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部笔记"
        case .favorites: return "收藏笔记"
        case .unreviewed: return "未复习笔记"
        case .currentBook: return "当前书籍"
        }
    }

    var subtitle: String {
        switch self {
        case .all: return "完整导出你的书摘库"
        case .favorites: return "只导出标星内容"
        case .unreviewed: return "整理成复习资料"
        case .currentBook: return "围绕正在阅读的书"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "tray.full"
        case .favorites: return "star"
        case .unreviewed: return "calendar"
        case .currentBook: return "book"
        }
    }
}

private extension ExportDocumentBuilder {
    func renderPreview() -> String {
        let packageMarkdown = (try? ExportDocumentBuilder(
            notes: notes,
            format: .markdown,
            template: template,
            customTemplate: customTemplate,
            baseFilename: baseFilename
        ).build().data)
        return packageMarkdown.flatMap { String(data: $0, encoding: .utf8) } ?? "预览生成失败。"
    }
}
