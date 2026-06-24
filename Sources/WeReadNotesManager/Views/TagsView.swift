import SwiftUI
import SwiftData

/// 标签管理视图：列出所有标签，可新建 / 重命名 / 删除。
struct TagsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var newTagName: String = ""
    @State private var renameTarget: Tag?
    @State private var renameDraft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                tagList
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
                Divider()
                tagDetail
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("标签")
                    .font(.system(size: 20, weight: .semibold))
                Text("为笔记打任意自定义标签，方便后续筛选和回顾。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                TextField("新标签名", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .onSubmit(createTag)
                Button("新建") { createTag() }
                    .buttonStyle(.borderedProminent)
                    .disabled(Tag.normalize(name: newTagName).isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var tagList: some View {
        List {
            if allTags.isEmpty {
                ContentUnavailableView(
                    "还没有标签",
                    systemImage: "tag",
                    description: Text("在上方输入名称创建第一个标签")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(allTags) { tag in
                    let color = colorFor(tag)
                    HStack(spacing: 10) {
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                        Text(tag.name)
                            .font(.system(size: 13))
                        Spacer()
                        Text("\(tag.notes.count)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        renameTarget = tag
                        renameDraft = tag.name
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            appVM.deleteTag(tag, context: modelContext)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        Button {
                            renameTarget = tag
                            renameDraft = tag.name
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .sheet(item: $renameTarget) { tag in
            renameSheet(for: tag)
        }
    }

    private var tagDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if allTags.isEmpty {
                    ContentUnavailableView(
                        "选择左侧标签查看详情",
                        systemImage: "tag",
                        description: Text("标签会显示使用次数和最近的笔记")
                    )
                } else {
                    ForEach(allTags) { tag in
                        let color = colorFor(tag)
                        TagDetailSection(tag: tag, color: color)
                    }
                }
            }
            .padding(20)
        }
    }

    private func createTag() {
        let normalized = Tag.normalize(name: newTagName)
        guard !normalized.isEmpty else { return }
        if appVM.findOrCreateTag(name: normalized, context: modelContext) != nil {
            newTagName = ""
        }
    }

    private func renameSheet(for tag: Tag) -> some View {
        VStack(spacing: 16) {
            Text("重命名标签")
                .font(.system(size: 16, weight: .semibold))
            TextField("新名称", text: $renameDraft)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { renameTarget = nil }
                Spacer()
                Button("保存") {
                    appVM.renameTag(tag, to: renameDraft, context: modelContext)
                    renameTarget = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(Tag.normalize(name: renameDraft).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

/// 工具：取 Tag 的 SwiftUI Color，避免在 @Model 实例上访问计算属性触发 binding 推断。
func colorFor(_ tag: Tag) -> Color {
    guard let hex = tag.colorHex else { return .accentColor }
    return Color(hex: hex) ?? .accentColor
}

private struct TagDetailSection: View {
    let tag: Tag
    let color: Color
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                Text(tag.name)
                    .font(.system(size: 16, weight: .semibold))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(tag.notes.count) 条笔记")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ForEach(tag.notes.prefix(8)) { note in
                NoteSummaryRow(note: note)
            }
            if tag.notes.count > 8 {
                Text("还有 \(tag.notes.count - 8) 条...")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .glassPanel()
    }
}

private struct NoteSummaryRow: View {
    let note: ReadingNote
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        Button {
            appVM.selectedNote = note
            if let book = note.book {
                appVM.selectedBook = book
                appVM.selectedSidebarItem = .books
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                if let bookTitle = note.book?.title {
                    Text(bookTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(note.highlight)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

/// 标签 chip 编辑器（用于在 NoteDetailView 嵌入）。
struct TagChipEditor: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    let note: ReadingNote
    @State private var newTagName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("标签")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            FlowLayout(spacing: 6) {
                ForEach(note.tags) { tag in
                    let color = colorFor(tag)
                    Button {
                        appVM.removeTag(tag, from: note, context: modelContext)
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 6, height: 6)
                            Text(tag.name)
                                .font(.system(size: 11))
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(color.opacity(0.18)))
                        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                TextField("添加标签", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTag() }
                Button("添加") { addTag() }
                    .buttonStyle(.bordered)
                    .disabled(Tag.normalize(name: newTagName).isEmpty)
            }
        }
    }

    private func addTag() {
        let normalized = Tag.normalize(name: newTagName)
        guard !normalized.isEmpty,
              let tag = appVM.findOrCreateTag(name: normalized, context: modelContext) else {
            return
        }
        appVM.addTag(tag, to: note, context: modelContext)
        newTagName = ""
    }
}

/// 简单 Flow 布局（chip 用）。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let result = arrange(subviews: subviews, in: maxWidth)
        return CGSize(width: maxWidth == .infinity ? result.width : maxWidth, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews: subviews, in: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> (frames: [CGRect], width: CGFloat, height: CGFloat) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxRowWidth = max(maxRowWidth, x)
        }
        return (frames, maxRowWidth, y + rowHeight)
    }
}