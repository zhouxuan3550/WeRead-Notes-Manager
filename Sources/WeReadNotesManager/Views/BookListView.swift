import SwiftUI
import SwiftData

struct BookListView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @State private var showAddBook = false
    @State private var newBookTitle = ""
    @State private var newBookAuthor = ""
    @AppStorage("filterLowNoteBooksOnImport") private var filterLowNoteBooksOnImport = true
    @AppStorage("minNotesPerImportedBook") private var minNotesPerImportedBook = 5

    var body: some View {
        let visibleBooks = appVM.filteredBooks(
            filterLowNoteBooks: filterLowNoteBooksOnImport,
            minNotesPerBook: minNotesPerImportedBook
        )
        VStack(spacing: 0) {
            toolbar(visibleCount: visibleBooks.count)
            Divider()
            if visibleBooks.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "books.vertical")
                } description: {
                    Text(emptyDescription)
                } actions: {
                    HStack(spacing: 10) {
                        Button("添加书籍") {
                            showAddBook = true
                        }
                        .flatActionButton(.accent, height: 32)
                        Button("调整过滤规则") {
                            appVM.selectedSidebarItem = .settings
                        }
                        .flatActionButton(height: 32)
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 14)], spacing: 18) {
                        ForEach(visibleBooks) { book in
                            Button {
                                appVM.selectedBook = book
                                appVM.selectedNote = nil
                            } label: {
                                BookShelfCard(book: book, isSelected: appVM.selectedBook?.id == book.id)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("删除", role: .destructive) {
                                    appVM.deleteBook(book, context: modelContext)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .sheet(isPresented: $showAddBook) {
            addBookSheet
        }
    }

    private var bookSelection: Binding<UUID?> {
        Binding(
            get: { appVM.selectedBook?.id },
            set: { newID in
                appVM.selectedBook = appVM.filteredBooks(
                    filterLowNoteBooks: filterLowNoteBooksOnImport,
                    minNotesPerBook: minNotesPerImportedBook
                ).first { $0.id == newID }
                appVM.selectedNote = nil
            }
        )
    }

    private func toolbar(visibleCount: Int) -> some View {
        let stats = appVM.libraryStats
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("书籍")
                    .font(.system(size: 15, weight: .semibold))
                Text(bookStatsText(stats: stats, visibleCount: visibleCount))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showAddBook = true
            } label: {
                Image(systemName: "plus")
            }
            .help("添加书籍")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyTitle: String {
        if filterLowNoteBooksOnImport, !appVM.books.isEmpty {
            return "没有符合过滤规则的书籍"
        }
        return "暂无书籍"
    }

    private var emptyDescription: String {
        if filterLowNoteBooksOnImport, !appVM.books.isEmpty {
            return "当前隐藏了少于 \(minNotesPerImportedBook) 条笔记的书，可在设置里调整。"
        }
        return "点击上方 + 添加书籍，或导入笔记文件"
    }

    private func bookStatsText(stats: LibraryStats, visibleCount: Int) -> String {
        if filterLowNoteBooksOnImport, visibleCount != stats.bookCount {
            return "显示 \(visibleCount) / \(stats.bookCount) 本书 · \(stats.noteCount) 条笔记"
        }
        return "\(stats.bookCount) 本书 · \(stats.noteCount) 条笔记"
    }

    private var addBookSheet: some View {
        VStack(spacing: 16) {
            Text("添加书籍")
                .font(.system(size: 18, weight: .semibold))
            TextField("书名", text: $newBookTitle)
                .textFieldStyle(.roundedBorder)
            TextField("作者（可选）", text: $newBookAuthor)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") {
                    showAddBook = false
                    newBookTitle = ""
                    newBookAuthor = ""
                }
                Spacer()
                Button("添加") {
                    guard !newBookTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let author = newBookAuthor.trimmingCharacters(in: .whitespaces)
                    appVM.addBook(title: newBookTitle, author: author.isEmpty ? nil : author, context: modelContext)
                    showAddBook = false
                    newBookTitle = ""
                    newBookAuthor = ""
                }
                .flatActionButton(.accent, height: 32)
                .disabled(newBookTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

struct BookShelfCard: View {
    let book: Book
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        // 一次性算 thoughtCount，避免 contains + filter 走两遍。
        let thoughtCount = book.notes.lazy.filter { $0.userNote?.isEmpty == false }.count
        VStack(alignment: .leading, spacing: 9) {
            BookCoverView(book: book, size: .large)
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                Text(book.author ?? "未知作者")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(book.notes.count) 条笔记")
                    if thoughtCount > 0 {
                        Text("· \(thoughtCount) 想法")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .glassPanel(isHighlighted: isSelected)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
