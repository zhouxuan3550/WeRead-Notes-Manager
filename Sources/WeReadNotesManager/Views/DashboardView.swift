import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.themePalette) private var palette
    @Binding var searchText: String
    let isAutoSyncEnabled: Bool
    let isSyncing: Bool
    let syncState: SyncState
    let onImport: () -> Void
    let onExport: () -> Void
    let onSync: () -> Void
    let onSearch: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CommandBar(
                    searchText: $searchText,
                    isAutoSyncEnabled: isAutoSyncEnabled,
                    isSyncing: isSyncing,
                    onImport: onImport,
                    onExport: onExport,
                    onSync: onSync,
                    onSearch: onSearch
                )
                .onChange(of: searchText) { _, newValue in
                    if !newValue.isEmpty {
                        onSearch()
                    }
                }
                SyncStatusCard(syncState: syncState, onRetry: onSync)
                hero
                recentShelf
                memoryStats
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    private var hero: some View {
        let reviewCount = appVM.reviewRecommendedNotes().count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Text("今日温故")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(0)
                if featuredNote != nil {
                    LiveBadge()
                }
            }
            Text("从你的微信读书笔记里，挑一条今天值得重看的。")
                .font(.system(size: 14))
                .foregroundStyle(palette.textSecondary)

            HStack(alignment: .top, spacing: 24) {
                if let note = featuredNote {
                    Button {
                        appVM.selectedNote = note
                    } label: {
                        FeaturedNoteCard(note: note)
                    }
                    .buttonStyle(.plain)
                } else {
                    ContentUnavailableView("还没有可温故的笔记", systemImage: "sparkles", description: Text("同步微信读书后，这里会出现今日精选"))
                        .frame(minHeight: 156)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("今天")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    quickAction("复习 \(reviewCount) 条", icon: "rectangle.stack") {
                        appVM.selectedSidebarItem = .todayReview
                    }
                    quickAction("打开书架", icon: "books.vertical") {
                        appVM.selectedSidebarItem = .books
                    }
                    quickAction("搜索笔记", icon: "magnifyingglass") {
                        appVM.selectedSidebarItem = .allNotes
                    }
                    quickAction("阅读报告", icon: "doc.text.magnifyingglass") {
                        appVM.selectedSidebarItem = .readingReport
                    }
                }
                .frame(width: 176)
            }
        }
    }

    private func quickAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(palette.surfaceElevated.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 0.8)
        )
    }

    private var recentShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("最近的书")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("全部书籍") {
                    appVM.selectedSidebarItem = .books
                }
                .flatActionButton(height: 28)
            }

            let books = Array(appVM.books.sorted { ($0.lastImportedAt ?? $0.updatedAt) > ($1.lastImportedAt ?? $1.updatedAt) }.prefix(8))
            if books.isEmpty {
                Text("同步后会在这里看到你的微信读书封面墙。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(books) { book in
                            Button {
                                appVM.selectedBook = book
                                appVM.selectedNote = nil
                                appVM.selectedSidebarItem = .books
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    BookCoverView(book: book, size: .large)
                                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                    Text(book.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(2)
                                        .frame(width: 82, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var memoryStats: some View {
        let stats = appVM.libraryStats
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            Button {
                appVM.selectedSidebarItem = .books
            } label: {
                statCard("书籍", value: "\(stats.bookCount)", icon: "books.vertical")
            }
            .buttonStyle(.plain)
            
            Button {
                appVM.selectedSidebarItem = .allNotes
            } label: {
                statCard("笔记", value: "\(stats.noteCount)", icon: "note.text")
            }
            .buttonStyle(.plain)
            
            Button {
                appVM.selectedSidebarItem = .allNotes
            } label: {
                statCard("想法", value: "\(stats.thoughtCount)", icon: "quote.bubble")
            }
            .buttonStyle(.plain)
            
            Button {
                appVM.selectedSidebarItem = .todayReview
            } label: {
                statCard("待复习", value: "\(stats.unreviewedCount)", icon: "calendar")
            }
            .buttonStyle(.plain)
        }
    }

    private func statCard(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 6).fill(palette.textPrimary.opacity(0.045)))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private var featuredNote: ReadingNote? {
        appVM.reviewRecommendedNotes().first ?? appVM.allNotes.randomElement()
    }
}

private struct SyncStatusCard: View {
    let syncState: SyncState
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: syncState.isSyncing ? "arrow.triangle.2.circlepath" : (syncState.lastError == nil ? "checkmark.circle" : "exclamationmark.triangle"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(syncState.lastError == nil ? Color.secondary : Color.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let progress = syncState.progress {
                    ProgressView(value: progress.fractionCompleted)
                        .controlSize(.small)
                }
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if syncState.lastError != nil {
                Button("重试", action: onRetry)
                    .flatActionButton(height: 30)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassPanel()
    }

    private var title: String {
        if syncState.isSyncing { return "正在同步微信读书" }
        if syncState.lastError != nil { return "同步失败" }
        if syncState.lastSyncedAt != nil { return "同步完成" }
        return "尚未同步"
    }

    private var detail: String {
        if let error = syncState.lastError { return error }
        if let message = syncState.lastMessage { return message }
        if let date = syncState.lastSyncedAt { return "上次同步：\(date.shortString)" }
        return "需要更新时手动同步，启动时不会自动拉取"
    }
}

struct FeaturedNoteCard: View {
    let note: ReadingNote

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                if let book = note.book {
                    BookCoverView(book: book, size: .small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(book.author ?? "未知作者")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
            }

            Text(note.highlight)
                .font(.system(size: 17, weight: .medium))
                .lineSpacing(5)
                .lineLimit(6)

            if let userNote = note.userNote, !userNote.isEmpty {
                Text(userNote)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .glassPanel()
    }
}

// MARK: - LiveBadge：呼吸光点

struct LiveBadge: View {
    @Environment(\.themePalette) private var palette

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(palette.accent)
                .frame(width: 6, height: 6)
            Text("今日")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(palette.accent.opacity(0.12))
        )
    }
}

struct BookCoverView: View {
    enum Size: Equatable {
        case small
        case medium
        case large
        case custom(width: CGFloat, height: CGFloat)

        var width: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 48
            case .large: return 82
            case .custom(let w, _): return w
            }
        }

        var height: CGFloat {
            switch self {
            case .small, .medium, .large: return width * 1.36
            case .custom(_, let h): return h
            }
        }

        static func == (lhs: Size, rhs: Size) -> Bool {
            lhs.width == rhs.width && lhs.height == rhs.height
        }

        /// 大尺寸 custom（>100 宽）—— 决定是否显示副标题
        var sizeIsLargeCustom: Bool {
            if case .custom(let w, _) = self, w > 100 { return true }
            return false
        }
    }

    let book: Book
    let size: Size

    @Environment(\.themePalette) private var palette

    var body: some View {
        Group {
            if let coverURL = book.coverURL, let url = URL(string: coverURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: max(3, size.width * 0.05)))
        .overlay(
            RoundedRectangle(cornerRadius: max(3, size.width * 0.05))
                .stroke(palette.borderMedium, lineWidth: 1)
        )
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    palette.surfaceElevated,
                    palette.surface.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 2) {
                Text(String(book.title.prefix(1)))
                    .font(.system(size: size.width * 0.38, weight: .bold, design: .serif))
                    .foregroundStyle(palette.textPrimary.opacity(0.7))
                if size == .large || size.sizeIsLargeCustom {
                    Text(book.title.count > 2 ? String(book.title.suffix(book.title.count - 2).prefix(2)) : "")
                        .font(.system(size: max(8, size.width * 0.11), weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
