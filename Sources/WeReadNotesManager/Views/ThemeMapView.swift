import SwiftUI

struct ThemeMapView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var selectedTheme: ThemeCluster?
    @State private var viewMode: ViewMode = .byTheme
    
    enum ViewMode: String, CaseIterable {
        case byTheme = "按主题"
        case byBook = "按书籍"
    }

    var body: some View {
        let clusters = ReadingInsightService.themeClusters(from: appVM.books)
        let books = appVM.books.sorted { $0.notes.count > $1.notes.count }

        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    
                    // 视图切换器
                    Picker("分类方式", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if viewMode == .byTheme {
                        if clusters.isEmpty {
                            ContentUnavailableView("主题还不够明显", systemImage: "point.3.connected.trianglepath.dotted", description: Text("同步更多笔记后，会自动形成主题地图"))
                                .frame(maxWidth: .infinity, minHeight: 280)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                                ForEach(clusters) { cluster in
                                    Button {
                                        selectedTheme = cluster
                                    } label: {
                                        ThemeBubble(cluster: cluster, isSelected: selectedTheme?.id == cluster.id)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        // 按书籍分组
                        if books.isEmpty {
                            ContentUnavailableView("还没有书籍", systemImage: "books.vertical", description: Text("同步微信读书后会显示在这里"))
                                .frame(maxWidth: .infinity, minHeight: 280)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                                ForEach(books) { book in
                                    BookBubble(book: book)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            if viewMode == .byTheme {
                ThemeDetailView(cluster: selectedTheme ?? clusters.first)
                    .frame(width: 320)
            } else {
                BookDetailView()
                    .frame(width: 320)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("主题地图")
                .font(.system(size: 24, weight: .bold))
            Text("从划线和想法里抽取反复出现的主题，看见书与书之间的连接。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

struct ThemeBubble: View {
    let cluster: ThemeCluster
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(cluster.title)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
            Text("\(cluster.count) 条笔记 · \(cluster.books.count) 本书")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: -8) {
                ForEach(cluster.books.prefix(4)) { book in
                    BookCoverView(book: book, size: .small)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .glassPanel(isHighlighted: isSelected)
    }
}

struct ThemeDetailView: View {
    let cluster: ThemeCluster?
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let cluster {
                Text(cluster.title)
                    .font(.system(size: 20, weight: .bold))
                Text("\(cluster.count) 条相关笔记")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text("相关书籍")
                    .font(.system(size: 14, weight: .semibold))
                ForEach(cluster.books.prefix(5)) { book in
                    Button {
                        appVM.selectedBook = book
                        appVM.selectedSidebarItem = .books
                    } label: {
                        HStack(spacing: 10) {
                            BookCoverView(book: book, size: .small)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Text(book.author ?? "未知作者")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                Text("相关摘录")
                    .font(.system(size: 14, weight: .semibold))
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(cluster.notes.prefix(8)) { note in
                            Button {
                                appVM.selectedNote = note
                            } label: {
                                Text(note.highlight)
                                    .font(.system(size: 12))
                                    .lineLimit(4)
                                    .foregroundStyle(.primary)
                                    .padding(10)
                                    .glassPanel(cornerRadius: 7)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                ContentUnavailableView("选择一个主题", systemImage: "sparkles")
            }
            Spacer()
        }
        .padding(18)
    }
}

struct BookBubble: View {
    let book: Book
    @Environment(AppViewModel.self) private var appVM
    @State private var isSelected = false

    var body: some View {
        Button {
            // 只选中这本书，不跳转
            appVM.selectedBook = book
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    BookCoverView(book: book, size: .medium)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(2)
                        if let author = book.author {
                            Text(author)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Label("\(book.notes.count)", systemImage: "note.text")
                    if book.notes.contains(where: { $0.isFavorite }) {
                        Label("\(book.notes.filter { $0.isFavorite }.count)", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .glassPanel(isHighlighted: isSelected)
        }
        .buttonStyle(.plain)
        .onAppear {
            isSelected = appVM.selectedBook?.id == book.id
        }
        .onChange(of: appVM.selectedBook?.id) { _, newId in
            isSelected = newId == book.id
        }
    }
}

struct BookDetailView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let book = appVM.selectedBook ?? appVM.books.first {
                    HStack(alignment: .top, spacing: 12) {
                        BookCoverView(book: book, size: .large)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.system(size: 16, weight: .bold))
                                .lineLimit(3)
                            if let author = book.author {
                                Text(author)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Text("笔记统计")
                        .font(.system(size: 13, weight: .semibold))
                    
                    let favoriteCount = book.notes.filter { $0.isFavorite }.count
                    let thoughtCount = book.notes.filter { $0.userNote?.isEmpty == false }.count
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(book.notes.count)")
                                .font(.system(size: 18, weight: .bold))
                            Text("总笔记")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(favoriteCount)")
                                .font(.system(size: 18, weight: .bold))
                            Text("收藏")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(thoughtCount)")
                                .font(.system(size: 18, weight: .bold))
                            Text("想法")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    Text("章节分布")
                        .font(.system(size: 13, weight: .semibold))
                    
                    let chapterGroups = Dictionary(grouping: book.notes) { $0.chapter?.isEmpty == false ? $0.chapter! : "未分章" }
                    let sortedChapters = chapterGroups
                        .map { (title: $0.key, count: $0.value.count) }
                        .sorted { $0.count > $1.count }
                        .prefix(8)
                    
                    ForEach(Array(sortedChapters), id: \.title) { chapter, count in
                        HStack {
                            Text(chapter)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        appVM.selectedBook = book
                        appVM.selectedSidebarItem = .books
                    } label: {
                        Label("打开这本书", systemImage: "book")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    ContentUnavailableView("选择一本书", systemImage: "books.vertical")
                }
                Spacer()
            }
            .padding(18)
        }
    }
}
