import SwiftUI
import SwiftData

/// 批量操作工具栏：选中多条笔记后显示。
struct BatchOperationToolbar: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    let selectedNotes: [ReadingNote]
    let onClear: () -> Void

    @State private var showTagPicker = false
    @State private var showMovePicker = false
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Text("已选 \(selectedNotes.count) 条")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Divider().frame(height: 16)

            Button {
                appVM.batchToggleFavorite(selectedNotes, context: modelContext, favorite: true)
                onClear()
            } label: {
                Label("收藏", systemImage: "star.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            Button {
                appVM.batchMarkReviewed(selectedNotes, context: modelContext)
                onClear()
            } label: {
                Label("标记复习", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            Button {
                showTagPicker = true
            } label: {
                Label("打标签", systemImage: "tag.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            if appVM.selectedBook == nil {
                Button {
                    showMovePicker = true
                } label: {
                    Label("移到...", systemImage: "folder.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("取消选择", action: onClear)
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
        .sheet(isPresented: $showTagPicker) {
            BatchTagPickerSheet(selectedNotes: selectedNotes)
        }
        .sheet(isPresented: $showMovePicker) {
            BatchMoveBookSheet(selectedNotes: selectedNotes)
        }
        .confirmationDialog(
            "删除 \(selectedNotes.count) 条笔记？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("移到回收站", role: .destructive) {
                appVM.batchDeleteNotes(selectedNotes, context: modelContext)
                onClear()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("可在回收站中恢复。")
        }
    }
}

/// 批量打标签 sheet。
private struct BatchTagPickerSheet: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var allTags: [Tag]
    let selectedNotes: [ReadingNote]
    @State private var newTagName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("批量打标签")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("新建标签", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                    Button("添加") {
                        guard let tag = appVM.findOrCreateTag(name: newTagName, context: modelContext) else { return }
                        appVM.batchAddTag(tag, to: selectedNotes, context: modelContext)
                        newTagName = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(Tag.normalize(name: newTagName).isEmpty)
                }

                Text("已有标签")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                if allTags.isEmpty {
                    Text("还没有标签")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(allTags) { tag in
                            let alreadyOn = selectedNotes.allSatisfy { $0.tags.contains(where: { $0.id == tag.id }) }
                            Button {
                                if alreadyOn {
                                    appVM.batchRemoveTag(tag, from: selectedNotes, context: modelContext)
                                } else {
                                    appVM.batchAddTag(tag, to: selectedNotes, context: modelContext)
                                }
                            } label: {
                                let color = colorFor(tag)
                                HStack(spacing: 4) {
                                    Image(systemName: alreadyOn ? "checkmark" : "plus")
                                        .font(.system(size: 9))
                                    Text(tag.name)
                                        .font(.system(size: 12))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(color.opacity(alreadyOn ? 0.35 : 0.15)))
                                .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 480, height: 380)
    }
}

/// 批量移到另一本书 sheet。
private struct BatchMoveBookSheet: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Book.title) private var allBooks: [Book]
    let selectedNotes: [ReadingNote]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("移到其他书")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            List {
                ForEach(allBooks) { book in
                    Button {
                        appVM.batchMoveNotes(selectedNotes, to: book, context: modelContext)
                        dismiss()
                    } label: {
                        HStack {
                            Text(book.title)
                                .font(.system(size: 13))
                            Spacer()
                            Text(book.author ?? "")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 440, height: 420)
    }
}