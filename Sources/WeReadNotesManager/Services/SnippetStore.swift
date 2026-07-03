import Foundation
import SwiftUI

// MARK: - 快捷短语模板
//
// 用户预设常用的笔记模板，一键插入：
// - "我的理解：..."
// - "行动：明天..."
// - "反方观点：..."
//
// 存储在 JSON：/Library/Application Support/书摘温故/snippets.json

struct Snippet: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var shortcut: String  // 触发关键词，比如 "act"
    var body: String
    var category: String
    var isBuiltIn: Bool = false
}

@MainActor
@Observable
final class SnippetStore {
    static let shared = SnippetStore()

    var snippets: [Snippet] = []

    private init() {
        load()
    }

    static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return support
            .appendingPathComponent("书摘温故", isDirectory: true)
            .appendingPathComponent("snippets.json")
    }

    func load() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = saved
        } else {
            snippets = Self.builtInSnippets
            persist()
        }
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    func add(_ snippet: Snippet) {
        snippets.append(snippet)
        persist()
    }

    func update(_ snippet: Snippet) {
        if let idx = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[idx] = snippet
            persist()
        }
    }

    func remove(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        persist()
    }

    /// 通过触发关键词查找
    func snippet(for shortcut: String) -> Snippet? {
        snippets.first { $0.shortcut.lowercased() == shortcut.lowercased() }
    }

    static let builtInSnippets: [Snippet] = [
        Snippet(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "我的理解",
            shortcut: "my",
            body: "我的理解：",
            category: "想法",
            isBuiltIn: true
        ),
        Snippet(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "立刻行动",
            shortcut: "act",
            body: "行动：立刻 → ",
            category: "行动",
            isBuiltIn: true
        ),
        Snippet(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "反方观点",
            shortcut: "con",
            body: "反方观点：",
            category: "思考",
            isBuiltIn: true
        ),
        Snippet(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "关联到",
            shortcut: "link",
            body: "关联：[[]]",
            category: "结构",
            isBuiltIn: true
        ),
        Snippet(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            title: "本周启发",
            shortcut: "ins",
            body: "本周启发：",
            category: "总结",
            isBuiltIn: true
        ),
        Snippet(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            title: "经典金句",
            shortcut: "q",
            body: "> 金句：",
            category: "整理",
            isBuiltIn: true
        )
    ]
}

// MARK: - 短语编辑器

struct SnippetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themePalette) private var palette

    @State private var snippet: Snippet
    let onSave: (Snippet) -> Void
    let onDelete: () -> Void

    init(snippet: Snippet, onSave: @escaping (Snippet) -> Void, onDelete: @escaping () -> Void) {
        self._snippet = State(initialValue: snippet)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "text.cursor")
                    .foregroundStyle(palette.accent)
                Text(snippet.isBuiltIn ? "编辑短语" : (snippet.title.isEmpty ? "新建短语" : "编辑短语"))
                    .font(.headline)
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                TextField("标题", text: $snippet.title)
                    .textFieldStyle(.roundedBorder)
                TextField("触发词（如 act）", text: $snippet.shortcut)
                    .textFieldStyle(.roundedBorder)
                Picker("分类", selection: $snippet.category) {
                    ForEach(["想法", "行动", "思考", "结构", "总结", "整理", "其他"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)

                Text("内容")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                TextEditor(text: $snippet.body)
                    .font(.system(size: 13))
                    .frame(minHeight: 80)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(palette.surface))
            }
            .padding(16)

            Divider()

            HStack {
                if !snippet.isBuiltIn {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .flatActionButton(height: 32)
                }
                Spacer()
                Button("保存") {
                    onSave(snippet)
                    dismiss()
                }
                .flatActionButton(.accent, height: 32)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 480, height: 380)
    }
}

// MARK: - 短语管理 UI

struct SnippetListView: View {
    @State private var store = SnippetStore.shared
    @State private var editingSnippet: Snippet?
    @State private var isAdding = false

    @Environment(\.themePalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "text.cursor")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text("快捷短语")
                    .font(.headline)
                Spacer()
                Button {
                    isAdding = true
                } label: {
                    Label("新建", systemImage: "plus")
                }
                .flatActionButton(height: 32)
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(store.snippets) { snippet in
                        snippetRow(snippet)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 560, height: 480)
        .sheet(isPresented: $isAdding) {
            SnippetEditorView(
                snippet: Snippet(title: "", shortcut: "", body: "", category: "想法"),
                onSave: { newSnippet in
                    store.add(newSnippet)
                },
                onDelete: {}
            )
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditorView(
                snippet: snippet,
                onSave: { updated in
                    store.update(updated)
                },
                onDelete: {
                    store.remove(snippet)
                }
            )
        }
    }

    private func snippetRow(_ snippet: Snippet) -> some View {
        Button {
            editingSnippet = snippet
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text(snippet.body)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("触发：/\(snippet.shortcut)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.accent)
                    Text(snippet.category)
                        .font(.system(size: 10))
                        .foregroundStyle(palette.textTertiary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6).fill(palette.surface.opacity(0.5)))
        }
        .buttonStyle(.plain)
    }
}