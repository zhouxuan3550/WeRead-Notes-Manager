import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @State private var appVM = AppViewModel()
    @State private var showImport = false
    @State private var showExport = false
    @State private var showOCR = false
    @State private var autoSyncTask: Task<Void, Never>?
    @State private var syncError: String?
    @AppStorage("iCloudSnapshotSyncEnabled") private var iCloudSnapshotSyncEnabled = false
    @AppStorage("skipDuplicates") private var skipDuplicates = true
    @AppStorage("filterLowNoteBooksOnImport") private var filterLowNoteBooksOnImport = true
    @AppStorage("minNotesPerImportedBook") private var minNotesPerImportedBook = 5

    private var modelContainer: ModelContainer { modelContext.container }

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            WorkbenchPanel {
                mainContent
            }
        }
        .background(AmbientBackground(showGlows: false, showNoise: false, showDots: false))
        .globalErrorBanner()
        .environment(appVM)
        .sheet(isPresented: $showImport) {
            ImportView()
                .frame(width: 560, height: 560)
                .environment(appVM)
        }
        .sheet(isPresented: $showExport) {
            ExportView()
                .frame(width: 400, height: 320)
                .environment(appVM)
        }
        .sheet(isPresented: $showOCR) {
            OCRCaptureView()
                .environment(appVM)
                .environment(\.modelContext, modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .ocrCaptureRequested)) { _ in
            showOCR = true
        }
        .alert("同步失败", isPresented: Binding(
            get: { syncError != nil },
            set: { if !$0 { syncError = nil } }
        )) {
            Button("好") {}
            Button("打开导入设置") {
                showImport = true
            }
        } message: {
            Text(syncError ?? "")
        }
        .onAppear {
            appVM.seedIfEmpty(context: modelContext)
            appVM.refreshBooks(context: modelContext)
            appVM.purgeExpiredNotes(context: modelContext)
            AutoBackupService.purgeExpired()
            AutoBackupService.runIfNeeded(container: modelContainer)
            BackgroundSyncService.shared.install(container: modelContainer, context: modelContext)
            uploadICloudSnapshotIfNeeded()

            // 启动 3 秒后做 Spotlight 全量索引（不阻塞首屏）
            let books = appVM.books
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await SpotlightService.indexAll(books: books)
            }

            // 启动 2 秒后推送 Widget 数据
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                syncWidgetData()
            }
        }
        .onChange(of: books) { _, newBooks in
            appVM.updateBooks(newBooks)
            // 增量同步 Spotlight
            Task { await SpotlightService.indexAll(books: newBooks) }
            // 同步 Widget 数据
            syncWidgetData()
        }
        .background {
            Button("") { showImport = true }
                .keyboardShortcut("i", modifiers: .command)
                .hidden()
            Button("") { showExport = true }
                .keyboardShortcut("e", modifiers: .command)
                .hidden()
            Button("") { appVM.selectedSidebarItem = .allNotes }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
            Button("") { appVM.selectedSidebarItem = .todayReview }
                .keyboardShortcut("r", modifiers: .command)
                .hidden()
            Button("") { appVM.selectedSidebarItem = .dashboard }
                .keyboardShortcut("1", modifiers: .command)
                .hidden()
            Button("") { appVM.selectedSidebarItem = .books }
                .keyboardShortcut("2", modifiers: .command)
                .hidden()
            Button("") { appVM.selectedSidebarItem = .settings }
                .keyboardShortcut(",", modifiers: .command)
                .hidden()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let note = appVM.selectedNote {
            NoteDetailView(note: note)
        } else if let book = appVM.selectedBook {
            BookNotesView(book: book)
        } else {
            contentColumn
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        @Bindable var bindable = appVM
        switch appVM.selectedSidebarItem {
        case .dashboard:
            DashboardView(
                searchText: $bindable.searchText,
                isAutoSyncEnabled: false,
                isSyncing: autoSyncTask != nil,
                syncState: appVM.syncState,
                onImport: { showImport = true },
                onExport: { showExport = true },
                onSync: startToolbarSync,
                onSearch: {
                    appVM.selectedSidebarItem = .allNotes
                }
            )
        case .books:
            BookListView()
        case .settings:
            SettingsView()
        case .todayReview:
            ReviewView()
        case .randomNotes:
            RandomNoteView()
        case .mindMap:
            MindMapView()
        case .readingReport:
            ReadingReportView()
        case .allNotes:
            SearchCenterView()
        case .favorites, .unreviewed:
            NoteListView()
        case .tags:
            TagsView()
        case .topicClusters:
            TopicClustersView()
        case .knowledgeGraph:
            KnowledgeGraphView()
        case .writingCards:
            WritingCardsView()
        case .askAI:
            CrossNoteAskView()
        case .writingAssistant:
            AIWritingAssistantView()
        case .trash:
            TrashView()
        case .syncHistory:
            SyncHistoryView()
        case .none:
            ContentUnavailableView("选择左侧栏目", systemImage: "sidebar.left")
        }
    }

    private func syncWidgetData() {
        let dueCount = appVM.dueNotes.count
        let totalCount = appVM.allNotes.count
        let themeRaw = ThemeStore.shared.current.rawValue
        let topNotes = appVM.dueNotes.prefix(5).map { note in
            DueNotesEntry.WidgetNote(
                id: note.id.uuidString,
                bookTitle: note.book?.title ?? "未知",
                highlight: String(note.highlight.prefix(80)),
                chapter: note.chapter
            )
        }
        WidgetDataStore.shared.update(
            dueCount: dueCount,
            totalCount: totalCount,
            theme: themeRaw,
            topNotes: topNotes
        )
    }

    private func uploadICloudSnapshotIfNeeded() {
        guard iCloudSnapshotSyncEnabled, !appVM.allNotes.isEmpty else { return }
        do {
            _ = try ICloudSyncService.upload(books: appVM.books)
        } catch {
            appVM.syncState.lastError = "iCloud 上传失败：\(error.localizedDescription)"
        }
    }

    private func startToolbarSync() {
        guard let key = KeychainService.loadWeReadAPIKey(), !key.isEmpty else {
            showImport = true
            return
        }

        performWeReadSync(apiKey: key, fileName: "工具栏自动同步", showError: true)
    }

    private func performWeReadSync(apiKey: String, fileName: String, showError: Bool) {
        guard autoSyncTask == nil else { return }

        appVM.syncState.isSyncing = true
        appVM.syncState.lastError = nil
        appVM.syncState.lastMessage = "正在连接微信读书..."

        autoSyncTask = Task {
            let coordinator = ImportCoordinator(
                container: modelContainer,
                skipDuplicates: skipDuplicates,
                minNotesPerBook: filterLowNoteBooksOnImport ? minNotesPerImportedBook : 0
            )
            do {
                let summary = try await coordinator.syncWeRead(apiKey: apiKey) { progress in
                    appVM.syncState.progress = progress
                    appVM.syncState.lastMessage = progress.detail
                }
                appVM.refreshBooks(context: modelContext)
                appVM.syncState.lastSyncedAt = Date()
                appVM.syncState.lastMessage = summary.message
                appVM.syncState.lastError = nil
                appVM.syncState.progress = nil
                appVM.syncState.isSyncing = false
                autoSyncTask = nil
            } catch is CancellationError {
                appVM.syncState.lastMessage = "同步已取消"
                appVM.syncState.progress = nil
                appVM.syncState.isSyncing = false
                autoSyncTask = nil
            } catch {
                if showError {
                    syncError = UserFacingError.message(for: error, context: "同步微信读书")
                }
                appVM.syncState.lastError = UserFacingError.message(for: error, context: "同步微信读书")
                appVM.syncState.lastMessage = "同步失败"
                appVM.syncState.progress = nil
                appVM.syncState.isSyncing = false
                autoSyncTask = nil
            }
        }
    }
}
