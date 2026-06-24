import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var importResult: ImportResultSummary?
    @State private var isImporting = false
    @State private var apiKey = Self.initialAPIKey()
    @State private var syncMessage: String?
    @State private var syncProgress: WeReadSyncProgress?
    @State private var syncTask: Task<Void, Never>?
    @AppStorage("autoSyncOnLaunch") private var autoSyncOnLaunch = false

    private var modelContainer: ModelContainer { modelContext.container }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    weReadSkillPanel

                    importMethod(
                        title: "微信读书文本备选",
                        subtitle: "从微信读书复制或导出的 TXT，支持章节、划线和想法",
                        icon: "book.pages",
                        buttonTitle: "选择 TXT",
                        kind: .wereadText
                    )

                    importMethod(
                        title: "通用文件",
                        subtitle: "导入 Markdown 或普通 TXT 笔记文件",
                        icon: "doc.text",
                        buttonTitle: "选择文件",
                        kind: .general
                    )

                    if let importResult {
                        resultPanel(importResult)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 520, minHeight: 500)
        .onDisappear {
            cancelSync()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("导入笔记")
                    .font(.system(size: 18, weight: .semibold))
                Text("选择一种来源，导入完成后会自动去重并刷新列表")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("关闭") {
                cancelSync()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    private var weReadSkillPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.blue.opacity(0.14)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("微信读书 Skill 同步")
                        .font(.system(size: 15, weight: .semibold))
                    Text("通过 API Key 直接同步你的微信读书划线和想法")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            TextField("粘贴 wrk- 开头的 API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .disabled(isImporting)

            Toggle("启动软件后自动同步微信读书", isOn: $autoSyncOnLaunch)
                .font(.system(size: 13))
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            HStack(spacing: 10) {
                Button {
                    pasteAPIKeyFromClipboard()
                } label: {
                    Label("粘贴 Key", systemImage: "doc.on.clipboard")
                }
                .disabled(isImporting)

                Button {
                    saveAPIKey()
                    syncWeRead()
                } label: {
                    Label(isImporting ? "同步中..." : "同步微信读书笔记", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("保存 Key") {
                    saveAPIKey()
                }
                .disabled(isImporting || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("清除 Key") {
                    clearAPIKey()
                }
                .disabled(isImporting || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if isImporting {
                    Button("取消") {
                        cancelSync()
                    }
                }
            }

            if let syncMessage {
                Text(syncMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if let syncProgress {
                ProgressView(value: syncProgress.fractionCompleted) {
                    Text(syncProgress.title)
                        .font(.system(size: 12))
                } currentValueLabel: {
                    Text(syncProgress.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .glassPanel()
    }

    private func importMethod(
        title: String,
        subtitle: String,
        icon: String,
        buttonTitle: String,
        kind: ImportKind
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(buttonTitle) {
                chooseFile(kind)
            }
            .disabled(isImporting)
        }
        .padding(14)
        .glassPanel()
    }

    private func resultPanel(_ result: ImportResultSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(result.failedCount > 0 ? "导入完成，有部分失败" : "导入完成", systemImage: result.failedCount > 0 ? "exclamationmark.triangle" : "checkmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(result.failedCount > 0 ? .orange : .green)
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("文件：\(result.fileName)")
                Text("来源：\(result.sourceDisplayName)")
                HStack(spacing: 10) {
                    syncMetric("新增", result.notesCreated, .green)
                    syncMetric("重复", result.duplicatesSkipped, .orange)
                    syncMetric("失败", result.failedCount, result.failedCount > 0 ? .red : .secondary)
                }
                Text(result.message)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))
        }
        .padding(14)
        .glassPanel()
    }

    private func syncMetric(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 54, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 7).fill(.ultraThinMaterial))
    }

    private func chooseFile(_ kind: ImportKind) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = kind.allowedContentTypes
        panel.message = kind.panelMessage
        panel.prompt = "导入"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return
        }
        Task { await handleImport(url: url) }
    }

    private func saveAPIKey() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try KeychainService.saveWeReadAPIKey(key)
            UserDefaults.standard.removeObject(forKey: "wereadAPIKey")
            syncMessage = "API Key 已保存到本机 Keychain。"
        } catch {
            syncMessage = error.localizedDescription
        }
    }

    private func clearAPIKey() {
        do {
            try KeychainService.deleteWeReadAPIKey()
            UserDefaults.standard.removeObject(forKey: "wereadAPIKey")
            apiKey = ""
            syncMessage = "API Key 已清除。"
            syncProgress = nil
        } catch {
            syncMessage = error.localizedDescription
        }
    }

    private func pasteAPIKeyFromClipboard() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string) else {
            syncMessage = "剪贴板里没有可粘贴的文本。"
            return
        }

        if let key = extractAPIKey(from: clipboardText) {
            apiKey = key
            saveAPIKey()
            syncMessage = "已从剪贴板粘贴并保存 API Key。"
        } else {
            syncMessage = "没有在剪贴板文本中找到 wrk- 开头的 API Key。"
        }
    }

    private func extractAPIKey(from text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = Self.apiKeyRegex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }

    /// 微信读书 API Key 提取正则，进程内预编译一次。
    private static let apiKeyRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"wrk-[A-Za-z0-9_-]+"#)
    }()

    private func syncWeRead() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            importResult = ImportResultSummary(
                fileName: "微信读书同步",
                source: "weread_skill",
                notesCreated: 0,
                duplicatesSkipped: 0,
                failedCount: 1,
                message: "请先填写微信读书 API Key。"
            )
            return
        }

        isImporting = true
        syncMessage = "正在连接微信读书并同步笔记..."
        importResult = nil
        syncProgress = WeReadSyncProgress(current: 0, total: 1, bookTitle: "读取笔记本")

        syncTask?.cancel()
        syncTask = Task {
            let coordinator = ImportCoordinator(container: modelContainer)
            do {
                let summary = try await coordinator.syncWeRead(apiKey: key) { progress in
                    syncProgress = progress
                }
                importResult = ImportResultSummary(
                    fileName: summary.fileName,
                    source: summary.source,
                    notesCreated: summary.notesCreated,
                    duplicatesSkipped: summary.duplicatesSkipped,
                    failedCount: summary.failedCount,
                    message: summary.message
                )
                appVM.refreshBooks(context: modelContext)
                appVM.selectedSidebarItem = .books
                appVM.selectedBook = appVM.books.sorted { ($0.lastImportedAt ?? $0.updatedAt) > ($1.lastImportedAt ?? $1.updatedAt) }.first
                appVM.selectedNote = nil
                syncMessage = "同步完成。"
                syncProgress = nil
                syncTask = nil
                isImporting = false
            } catch is CancellationError {
                importResult = nil
                syncMessage = "同步已取消。"
                syncProgress = nil
                syncTask = nil
                isImporting = false
            } catch {
                importResult = ImportResultSummary(
                    fileName: "微信读书同步",
                    source: "weread_skill",
                    notesCreated: 0,
                    duplicatesSkipped: 0,
                    failedCount: 1,
                    message: error.localizedDescription
                )
                syncMessage = "同步失败。"
                syncProgress = nil
                syncTask = nil
                isImporting = false
            }
        }
    }

    private func cancelSync() {
        syncTask?.cancel()
        syncTask = nil
        if isImporting {
            isImporting = false
            syncProgress = nil
            syncMessage = "同步已取消。"
        }
    }

    private func handleImport(url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        isImporting = true
        defer { isImporting = false }

        let coordinator = ImportCoordinator(container: modelContainer)
        do {
            let summary = try await coordinator.importFile(url)
            importResult = ImportResultSummary(
                fileName: summary.fileName,
                source: summary.source,
                notesCreated: summary.notesCreated,
                duplicatesSkipped: summary.duplicatesSkipped,
                failedCount: summary.failedCount,
                message: summary.message
            )
            appVM.refreshBooks(context: modelContext)
            appVM.selectedSidebarItem = .books
            appVM.selectedBook = appVM.books.sorted { ($0.lastImportedAt ?? $0.updatedAt) > ($1.lastImportedAt ?? $1.updatedAt) }.first
            appVM.selectedNote = nil
        } catch {
            importResult = ImportResultSummary(
                fileName: url.lastPathComponent,
                source: "unknown",
                notesCreated: 0,
                duplicatesSkipped: 0,
                failedCount: 1,
                message: error.localizedDescription
            )
        }
    }

    private static func initialAPIKey() -> String {
        if let key = KeychainService.loadWeReadAPIKey() {
            return key
        }
        if let legacyKey = UserDefaults.standard.string(forKey: "wereadAPIKey"), !legacyKey.isEmpty {
            try? KeychainService.saveWeReadAPIKey(legacyKey)
            UserDefaults.standard.removeObject(forKey: "wereadAPIKey")
            return legacyKey
        }
        return ProcessInfo.processInfo.environment["WEREAD_API_KEY"] ?? ""
    }
}

private enum ImportKind {
    case wereadText
    case general

    var allowedContentTypes: [UTType] {
        switch self {
        case .wereadText:
            return [.plainText]
        case .general:
            return [.plainText, UTType(filenameExtension: "md")!, UTType(filenameExtension: "markdown")!]
        }
    }

    var panelMessage: String {
        switch self {
        case .wereadText:
            return "选择从微信读书复制或导出的 TXT 文件"
        case .general:
            return "选择 Markdown 或 TXT 笔记文件"
        }
    }
}

struct ImportResultSummary {
    let fileName: String
    let source: String
    let notesCreated: Int
    let duplicatesSkipped: Int
    let failedCount: Int
    let message: String

    var sourceDisplayName: String {
        switch source {
        case "weread_skill":
            return "微信读书 / Skill"
        case "markdown":
            return "Markdown"
        case "txt":
            return "TXT"
        default:
            return "未知"
        }
    }
}
