import SwiftUI

struct SearchCenterView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var selectedBookID: UUID?
    @State private var selectedChapter = "全部"
    @State private var onlyThoughts = false
    @State private var onlyFavorites = false

    var body: some View {
        let results = filteredResults
        VStack(spacing: 0) {
            header(resultCount: results.count)
            Divider().opacity(0.35)

            if results.isEmpty {
                ContentUnavailableView(
                    appVM.searchText.isEmpty ? "输入关键词开始搜索" : "没有匹配结果",
                    systemImage: "magnifyingglass",
                    description: Text(appVM.searchText.isEmpty ? "可以搜索书名、作者、章节、划线和想法" : "试试减少筛选条件")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedResults, id: \.book.id) { group in
                        Section {
                            ForEach(group.notes) { note in
                                SearchResultRow(note: note, query: appVM.searchText) {
                                    appVM.selectedBook = note.book
                                    appVM.selectedNote = note
                                }
                            }
                        } header: {
                            HStack {
                                Text(group.book.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(group.notes.count) 条")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func header(resultCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("搜索")
                        .font(.system(size: 22, weight: .semibold))
                    Text("\(resultCount) 条结果 · 按书籍分组")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
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
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.055)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))

            HStack(spacing: 10) {
                Picker("书籍", selection: $selectedBookID) {
                    Text("全部书籍").tag(UUID?.none)
                    ForEach(appVM.books) { book in
                        Text(book.title).tag(Optional(book.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Picker("章节", selection: $selectedChapter) {
                    ForEach(chapterOptions, id: \.self) { chapter in
                        Text(chapter).tag(chapter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)

                Toggle("有想法", isOn: $onlyThoughts)
                    .toggleStyle(.checkbox)

                Toggle("收藏", isOn: $onlyFavorites)
                    .toggleStyle(.checkbox)

                Spacer()

                Button("清除筛选") {
                    selectedBookID = nil
                    selectedChapter = "全部"
                    onlyThoughts = false
                    onlyFavorites = false
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 12))
        }
        .padding(18)
    }

    private var filteredResults: [ReadingNote] {
        appVM.searchNotes(
            query: appVM.searchText,
            bookID: selectedBookID,
            chapter: selectedChapter,
            onlyThoughts: onlyThoughts,
            onlyFavorites: onlyFavorites
        )
    }

    private var groupedResults: [(book: Book, notes: [ReadingNote])] {
        let grouped = Dictionary(grouping: filteredResults) { note in
            note.book ?? Book(title: "未知书籍", author: nil)
        }
        return grouped
            .map { ($0.key, $0.value) }
            .sorted { $0.0.title.localizedStandardCompare($1.0.title) == .orderedAscending }
    }

    private var chapterOptions: [String] {
        let notes: [ReadingNote]
        if let selectedBookID {
            notes = appVM.allNotes.filter { $0.book?.id == selectedBookID }
        } else {
            notes = appVM.allNotes
        }
        let chapters = Set(notes.map { $0.chapter?.isEmpty == false ? $0.chapter! : "未分章" })
        return ["全部"] + chapters.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

private struct SearchResultRow: View {
    let note: ReadingNote
    let query: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(note.chapter ?? "未分章")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if note.userNote?.isEmpty == false {
                        Label("想法", systemImage: "quote.bubble")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                    }
                }

                HighlightedSnippet(text: note.highlight, query: query)
                    .font(.system(size: 14))
                    .lineLimit(3)

                if let userNote = note.userNote, !userNote.isEmpty {
                    HighlightedSnippet(text: userNote, query: query)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct HighlightedSnippet: View {
    let text: String
    let query: String

    @Environment(\.themePalette) private var palette

    var body: some View {
        // 直接复用 HighlightedText 组件（多 token 高亮 + 主题感知）
        HighlightedText(text: text, query: query, font: .system(size: 14))
    }
}
