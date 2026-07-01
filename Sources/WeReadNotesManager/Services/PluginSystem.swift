import Foundation
import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

// MARK: - 插件系统
//
// 用户可以写自定义导出器：
// - 模板字符串 + 占位符（{{book.title}} / {{note.highlight}} 等）
// - 保存为 .wplugin 文件（JSON 格式）
// - 主 App 加载并集成到导出菜单
//
// 模板占位符语法：
//   {{book.title}}      - 书籍标题
//   {{book.author}}     - 作者
//   {{note.highlight}}  - 划线内容
//   {{note.userNote}}   - 用户想法
//   {{note.chapter}}    - 章节
//   {{note.tags}}       - 标签（逗号分隔）
//   {{note.location}}   - 位置
//   {{date}}            - 当前日期
//   {{index}}           - 当前序号（仅在批量导出时）

// MARK: - 插件模型

struct ExporterPlugin: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var icon: String
    var fileExtension: String
    var contentType: String   // "markdown" / "html" / "plain" / "csv"
    var template: String      // 主模板（多本书/多条笔记的整体结构）
    var noteTemplate: String  // 单条笔记模板
    var author: String?
    var version: String?
    var isBuiltIn: Bool = false

    static let builtInPlugins: [ExporterPlugin] = [
        ExporterPlugin(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Day One 日记",
            description: "导出为 Day One 兼容的 Markdown",
            icon: "book.closed",
            fileExtension: "md",
            contentType: "markdown",
            template: """
            # {{date}} 阅读记录

            今天读了 {{books.length}} 本书，整理如下。

            {{notes}}

            ## 统计

            - 笔记：{{books.notes.length}}
            - 想法：{{books.thoughts.length}}
            """,
            noteTemplate: """
            ### {{book.title}} {{book.author}}
            {{note.chapter}}

            > {{note.highlight}}

            {{note.userNote}}
            """,
            author: "书摘温故",
            version: "1.0",
            isBuiltIn: true
        ),
        ExporterPlugin(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Anki 闪卡",
            description: "生成 Anki 导入的制卡素材",
            icon: "rectangle.stack.badge.plus",
            fileExtension: "txt",
            contentType: "tsv",
            template: "{{notes}}",
            noteTemplate: "{{note.highlight}}\t{{note.userNote}}\t{{book.title}}",
            author: "书摘温故",
            version: "1.0",
            isBuiltIn: true
        ),
        ExporterPlugin(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "CSV 数据",
            description: "导出为 CSV（Excel 友好）",
            icon: "tablecells",
            fileExtension: "csv",
            contentType: "csv",
            template: "highlight,userNote,book,author,chapter,date,tags\n{{notes}}",
            noteTemplate: "\"\\{\\{note.highlight\\}\\}\",\"\\{\\{note.userNote\\}\\}\",\"\\{\\{book.title\\}\\}\",\"\\{\\{book.author\\}\\}\",\"\\{\\{note.chapter\\}\\}\",\"\\{\\{date\\}\\}\",\"\\{\\{note.tags\\}\\}\"",
            author: "书摘温故",
            version: "1.0",
            isBuiltIn: true
        )
    ]
}

// MARK: - 插件管理器

@MainActor
@Observable
final class PluginStore {
    static let shared = PluginStore()

    var plugins: [ExporterPlugin] = []

    private init() {
        load()
    }

    static var directoryURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return support.appendingPathComponent("书摘温故/Plugins", isDirectory: true)
    }

    func load() {
        plugins = ExporterPlugin.builtInPlugins

        // 扫描用户插件目录
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.directoryURL, withIntermediateDirectories: true)

        guard let files = try? fm.contentsOfDirectory(at: Self.directoryURL, includingPropertiesForKeys: nil) else {
            return
        }
        for fileURL in files where fileURL.pathExtension == "wplugin" {
            if let data = try? Data(contentsOf: fileURL),
               let plugin = try? JSONDecoder().decode(ExporterPlugin.self, from: data) {
                plugins.append(plugin)
            }
        }
    }

    func add(_ plugin: ExporterPlugin) {
        plugins.append(plugin)
        save(plugin)
    }

    func remove(_ plugin: ExporterPlugin) {
        plugins.removeAll { $0.id == plugin.id }
        if !plugin.isBuiltIn {
            let url = Self.directoryURL.appendingPathComponent("\(plugin.id).wplugin")
            try? FileManager.default.removeItem(at: url)
        }
    }

    func update(_ plugin: ExporterPlugin) {
        if let idx = plugins.firstIndex(where: { $0.id == plugin.id }) {
            plugins[idx] = plugin
            if !plugin.isBuiltIn {
                save(plugin)
            }
        }
    }

    private func save(_ plugin: ExporterPlugin) {
        guard let data = try? JSONEncoder().encode(plugin) else { return }
        let url = Self.directoryURL.appendingPathComponent("\(plugin.id).wplugin")
        try? data.write(to: url, options: .atomic)
    }

    func importPlugin(from url: URL) throws {
        let data = try Data(contentsOf: url)
        var plugin = try JSONDecoder().decode(ExporterPlugin.self, from: data)
        plugin.id = UUID()  // 重新分配 ID 避免冲突
        plugin.isBuiltIn = false
        add(plugin)
    }

    func exportPlugin(_ plugin: ExporterPlugin, to url: URL) throws {
        let data = try JSONEncoder().encode(plugin)
        try data.write(to: url)
    }
}

// MARK: - 模板渲染器

enum PluginRenderer {
    /// 渲染整个书籍/笔记集合
    static func render(
        plugin: ExporterPlugin,
        book: Book,
        notes: [ReadingNote]
    ) -> String {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let dateString = dateFormatter.string(from: now)

        // 渲染每条笔记
        var renderedNotes: [String] = []
        for (index, note) in notes.enumerated() {
            let rendered = renderNote(
                template: plugin.noteTemplate,
                note: note,
                book: book,
                index: index + 1,
                date: dateString
            )
            renderedNotes.append(rendered)
        }

        // 渲染整体模板
        var output = plugin.template
        output = output.replacingOccurrences(of: "{{date}}", with: dateString)
        output = output.replacingOccurrences(of: "{{books.length}}", with: "\(1)")
        output = output.replacingOccurrences(of: "{{books.notes.length}}", with: "\(book.notes.count)")
        output = output.replacingOccurrences(of: "{{books.thoughts.length}}", with: "\(book.notes.filter { ($0.userNote?.isEmpty == false) }.count)")
        output = output.replacingOccurrences(of: "{{notes}}", with: renderedNotes.joined(separator: "\n\n"))

        return output
    }

    /// 渲染单条笔记
    private static func renderNote(
        template: String,
        note: ReadingNote,
        book: Book,
        index: Int,
        date: String
    ) -> String {
        var result = template
        result = result.replacingOccurrences(of: "{{index}}", with: "\(index)")
        result = result.replacingOccurrences(of: "{{date}}", with: date)
        result = result.replacingOccurrences(of: "{{book.title}}", with: book.title)
        result = result.replacingOccurrences(of: "{{book.author}}", with: book.author ?? "未知")
        result = result.replacingOccurrences(of: "{{note.highlight}}", with: note.highlight)
        result = result.replacingOccurrences(of: "{{note.userNote}}", with: note.userNote ?? "")
        result = result.replacingOccurrences(of: "{{note.chapter}}", with: note.chapter ?? "")
        result = result.replacingOccurrences(of: "{{note.location}}", with: note.location ?? "")
        result = result.replacingOccurrences(of: "{{note.tags}}", with: note.tags.map { "#\($0.name)" }.joined(separator: " "))
        return result
    }
}

// MARK: - 插件编辑器

struct PluginEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themePalette) private var palette
    @State private var plugin: ExporterPlugin
    let onSave: (ExporterPlugin) -> Void

    init(plugin: ExporterPlugin, onSave: @escaping (ExporterPlugin) -> Void) {
        self._plugin = State(initialValue: plugin)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "puzzlepiece.extension")
                    .foregroundStyle(palette.accent)
                Text(plugin.name.isEmpty ? "新建插件" : "编辑插件")
                    .font(.headline)
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Group {
                        sectionTitle("基本信息")
                        TextField("插件名", text: $plugin.name)
                            .textFieldStyle(.roundedBorder)
                        TextField("描述", text: $plugin.description)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            TextField("图标 (SF Symbol)", text: $plugin.icon)
                                .textFieldStyle(.roundedBorder)
                            TextField("扩展名", text: $plugin.fileExtension)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }

                    sectionTitle("单条笔记模板")
                    Text("每条笔记按此模板渲染。可用占位符：{{note.highlight}} {{book.title}} 等")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                    TextEditor(text: $plugin.noteTemplate)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(palette.surface))

                    sectionTitle("整体模板")
                    Text("多本书/多条笔记的整体结构。用 {{notes}} 插入所有笔记")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                    TextEditor(text: $plugin.template)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(palette.surface))

                    // 预览
                    sectionTitle("预览")
                    if let firstBook = sampleBook {
                        let preview = PluginRenderer.render(plugin: plugin, book: firstBook, notes: Array(firstBook.notes.prefix(3)))
                        ScrollView(.horizontal) {
                            Text(preview)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(palette.surfaceElevated))
                        }
                        .frame(maxHeight: 180)
                    } else {
                        Text("同步笔记后可预览")
                            .font(.caption)
                            .foregroundStyle(palette.textTertiary)
                    }
                }
                .padding(16)
            }

            Divider()

            HStack {
                Spacer()
                Button("保存") {
                    onSave(plugin)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 640, height: 600)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.textPrimary)
            .padding(.top, 6)
    }

    private var sampleBook: Book? {
        // 预览功能：返回 nil（避免在编辑器中触发 SwiftData 初始化）
        nil
    }
}

// MARK: - 插件管理 UI

struct PluginListView: View {
    @State private var store = PluginStore.shared
    @State private var editingPlugin: ExporterPlugin?
    @State private var isAdding = false
    @State private var importStatus: String?

    @Environment(\.themePalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text("插件中心")
                    .font(.headline)
                Spacer()
                Button {
                    isAdding = true
                } label: {
                    Label("新建", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                Button("导入") { importFromFile() }
                    .buttonStyle(.bordered)
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.plugins) { plugin in
                        pluginRow(plugin)
                    }
                }
                .padding(16)
            }

            if let importStatus {
                Text(importStatus)
                    .font(.caption)
                    .foregroundStyle(palette.accent)
                    .padding(8)
            }
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $isAdding) {
            PluginEditorView(plugin: newPluginTemplate()) { new in
                store.add(new)
            }
        }
        .sheet(item: $editingPlugin) { plugin in
            PluginEditorView(plugin: plugin) { updated in
                store.update(updated)
            }
        }
    }

    private func newPluginTemplate() -> ExporterPlugin {
        ExporterPlugin(
            name: "我的导出器",
            description: "",
            icon: "doc.text",
            fileExtension: "md",
            contentType: "markdown",
            template: "# {{date}} 导出\n\n{{notes}}",
            noteTemplate: "## {{book.title}}\n\n{{note.highlight}}\n\n{{note.userNote}}",
            author: nil,
            version: "1.0",
            isBuiltIn: false
        )
    }

    private func pluginRow(_ plugin: ExporterPlugin) -> some View {
        HStack(spacing: 12) {
            Image(systemName: plugin.icon)
                .font(.system(size: 22))
                .foregroundStyle(palette.accent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(palette.accentSoft))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(plugin.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    if plugin.isBuiltIn {
                        Text("内置")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(palette.warning.opacity(0.18)))
                            .foregroundStyle(palette.warning)
                    }
                }
                Text(plugin.description)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    editingPlugin = plugin
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("编辑")

                if !plugin.isBuiltIn {
                    Button {
                        store.remove(plugin)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(palette.error)
                    }
                    .buttonStyle(.borderless)
                    .help("删除")
                }

                Button {
                    exportToFile(plugin)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .help("导出 .wplugin")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface.opacity(0.5)))
    }

    private func importFromFile() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        if let type = UTType(filenameExtension: "wplugin") {
            panel.allowedContentTypes = [type]
        }
        panel.allowsMultipleSelection = false
        panel.prompt = "导入"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try store.importPlugin(from: url)
                importStatus = "✅ 已导入"
            } catch {
                importStatus = "❌ 导入失败：\(error.localizedDescription)"
            }
        }
        #endif
    }

    private func exportToFile(_ plugin: ExporterPlugin) {
        #if canImport(AppKit)
        let panel = NSSavePanel()
        if let type = UTType(filenameExtension: "wplugin") {
            panel.allowedContentTypes = [type]
        }
        panel.nameFieldStringValue = "\(plugin.name).wplugin"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try store.exportPlugin(plugin, to: url)
                importStatus = "✅ 已导出"
            } catch {
                importStatus = "❌ 导出失败"
            }
        }
        #endif
    }
}

// MARK: - ModelContext 扩展

extension ModelContext {
    @MainActor
    static var sample: ModelContext {
        try! ModelContainer(for: Book.self, ReadingNote.self).mainContext
    }
}