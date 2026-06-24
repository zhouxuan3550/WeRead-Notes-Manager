import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @State private var appVM = AppViewModel()
    @State private var showImport = false
    @State private var showExport = false
    @State private var didAttemptAutoSync = false
    @State private var autoSyncTask: Task<Void, Never>?
    @State private var syncError: String?
    @AppStorage("autoSyncOnLaunch") private var autoSyncOnLaunch = false
    @AppStorage("iCloudSnapshotSyncEnabled") private var iCloudSnapshotSyncEnabled = false

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
        .background(AppBackdrop())
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
            startAutoSyncIfNeeded()

            // 启动 5 秒后做一次后台同步（不影响首屏）
            let container = modelContainer
            let context = modelContext
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await BackgroundSyncService.shared.runOnce(container: container, context: context)
                appVM.refreshBooks(context: context)
            }
        }
        .onChange(of: books) { _, newBooks in
            appVM.updateBooks(newBooks)
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
                isAutoSyncEnabled: autoSyncOnLaunch,
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
        case .themeMap:
            ThemeMapView()
        case .readingReport:
            ReadingReportView()
        case .allNotes:
            SearchCenterView()
        case .favorites, .unreviewed:
            NoteListView()
        case .tags:
            TagsView()
        case .askAI:
            CrossNoteAskView()
        case .trash:
            TrashView()
        case .syncHistory:
            SyncHistoryView()
        case .none:
            ContentUnavailableView("选择左侧栏目", systemImage: "sidebar.left")
        }
    }

    private func startAutoSyncIfNeeded() {
        guard autoSyncOnLaunch, !didAttemptAutoSync, autoSyncTask == nil else {
            return
        }
        didAttemptAutoSync = true

        guard let key = KeychainService.loadWeReadAPIKey(), !key.isEmpty else {
            return
        }

        performWeReadSync(apiKey: key, fileName: "启动自动同步", showError: false)
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
        autoSyncOnLaunch = true

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
            let coordinator = ImportCoordinator(container: modelContainer)
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
                    syncError = error.localizedDescription
                }
                appVM.syncState.lastError = error.localizedDescription
                appVM.syncState.lastMessage = "同步失败"
                appVM.syncState.progress = nil
                appVM.syncState.isSyncing = false
                autoSyncTask = nil
            }
        }
    }
}
