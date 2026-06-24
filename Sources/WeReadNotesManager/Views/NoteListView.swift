import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @State private var showAddNote = false
    @State private var isMultiSelectMode: Bool = false
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        let notes = appVM.filteredNotes
        VStack(spacing: 0) {
            toolbar(noteCount: notes.count)
            Divider()

            if isMultiSelectMode && !selectedIDs.isEmpty {
                BatchOperationToolbar(
                    selectedNotes: notes.filter { selectedIDs.contains($0.id) }
                ) {
                    selectedIDs.removeAll()
                    isMultiSelectMode = false
                }
            }

            if notes.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptyIcon,
                    description: Text(emptyDescription)
                )
            } else {
                List(selection: isMultiSelectMode ? $selectedIDs : .constant(Set<UUID>())) {
                    ForEach(notes) { note in
                        NoteRow(note: note)
                            .tag(note.id)
                            .contextMenu {
                                Button(note.isFavorite ? "取消收藏" : "收藏") {
                                    appVM.toggleFavorite(note)
                                }
                                Button("标记已复习") {
                                    appVM.markReviewed(note)
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    appVM.deleteNote(note, context: modelContext)
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showAddNote) {
            if let book = appVM.selectedBook ?? appVM.books.first {
                AddNoteSheet(book: book)
            }
        }
    }

    private func noteSelection(notes: [ReadingNote]) -> Binding<UUID?> {
        Binding(
            get: { appVM.selectedNote?.id },
            set: { newID in
                appVM.selectedNote = notes.first { $0.id == newID }
            }
        )
    }

    private var emptyTitle: String {
        if !appVM.searchText.isEmpty { return "未找到匹配笔记" }
        switch appVM.selectedSidebarItem {
        case .favorites: return "暂无收藏"
        case .unreviewed: return "所有笔记都已复习"
        default: return "暂无笔记"
        }
    }

    private var emptyIcon: String {
        switch appVM.selectedSidebarItem {
        case .favorites: return "star"
        case .unreviewed: return "checkmark.circle"
        default: return "note.text"
        }
    }

    private var emptyDescription: String {
        if !appVM.searchText.isEmpty { return "尝试其他关键词" }
        switch appVM.selectedSidebarItem {
        case .favorites: return "点击笔记旁的星标即可收藏"
        case .unreviewed: return "所有笔记都已复习过"
        default: return "导入笔记文件或手动添加"
        }
    }

    private func toolbar(noteCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(sectionTitle) (\(noteCount))")
                        .font(.system(size: 18, weight: .semibold))
                    Text(toolbarSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("类型", selection: Binding(
                    get: { appVM.noteKindFilter },
                    set: { appVM.noteKindFilter = $0 }
                )) {
                    ForEach(NoteKindFilter.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 92)

                Picker("排序", selection: Binding(
                    get: { appVM.noteSortMode },
                    set: { appVM.noteSortMode = $0 }
                )) {
                    ForEach(NoteSortMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 108)

                Button {
                    showAddNote = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("添加笔记")

                Button {
                    isMultiSelectMode.toggle()
                    if !isMultiSelectMode {
                        selectedIDs.removeAll()
                    }
                } label: {
                    Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .help("多选")
            }

            if appVM.selectedSidebarItem == .allNotes {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("搜索书名、作者、章节、划线或想法", text: Binding(
                        get: { appVM.searchText },
                        set: { appVM.searchText = $0 }
                    ))
                    .textFieldStyle(.plain)
                    if !appVM.searchText.isEmpty {
                        Button {
                            appVM.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var sectionTitle: String {
        if let book = appVM.selectedBook {
            return book.title
        }
        return appVM.selectedSidebarItem?.label ?? "笔记"
    }

    private var toolbarSubtitle: String {
        switch appVM.selectedSidebarItem {
        case .allNotes:
            return "在全部书摘和想法里快速定位"
        case .todayReview:
            return "按优先级重看值得复习的摘录"
        default:
            return "按书阅读请进入书架"
        }
    }
}

struct NoteRow: View {
    let note: ReadingNote

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if let bookTitle = note.book?.title {
                    Text(bookTitle)
                        .font(.caption)
                        .textSecondary()
                }
                if let chapter = note.chapter {
                    Text("· \(chapter)")
                        .font(.caption)
                        .textTertiary()
                }
                Spacer()
                HStack(spacing: 4) {
                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                    }
                    if note.isReviewed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                    }
                }
            }
            Text(note.highlight)
                .font(.system(size: 13))
                .lineLimit(2)
                .textPrimary()
            if let userNote = note.userNote, !userNote.isEmpty {
                Text(userNote)
                    .font(.caption)
                    .textSecondary()
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddNoteSheet: View {
    let book: Book
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var highlight = ""
    @State private var userNote = ""
    @State private var chapter = ""
    @State private var location = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("添加笔记 — \(book.title)")
                .font(.system(size: 18, weight: .semibold))
            TextField("章节（可选）", text: $chapter)
                .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: 4) {
                Text("划线内容")
                    .font(.system(size: 13, weight: .medium))
                TextEditor(text: $highlight)
                    .frame(minHeight: 80)
                    .border(.quaternary, width: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("我的想法（可选）")
                    .font(.system(size: 13, weight: .medium))
                TextEditor(text: $userNote)
                    .frame(minHeight: 60)
                    .border(.quaternary, width: 1)
            }
            TextField("位置 / 页码（可选）", text: $location)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("添加") {
                    let ch = chapter.trimmingCharacters(in: .whitespaces)
                    let loc = location.trimmingCharacters(in: .whitespaces)
                    let un = userNote.trimmingCharacters(in: .whitespaces)
                    appVM.addNote(
                        to: book,
                        highlight: highlight.trimmingCharacters(in: .whitespaces),
                        userNote: un.isEmpty ? nil : un,
                        chapter: ch.isEmpty ? nil : ch,
                        location: loc.isEmpty ? nil : loc,
                        context: modelContext
                    )
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(highlight.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440, height: 420)
    }
}
