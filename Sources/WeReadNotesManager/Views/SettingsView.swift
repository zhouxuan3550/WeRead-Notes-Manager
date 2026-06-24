import AppKit
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @AppStorage("skipDuplicates") private var skipDuplicates = true
    @AppStorage("autoOpenAfterImport") private var autoOpenAfterImport = true
    @AppStorage("autoSyncOnLaunch") private var autoSyncOnLaunch = false
    @AppStorage("autoBackupEnabled") private var autoBackupEnabled = true
    @AppStorage("iCloudSnapshotSyncEnabled") private var iCloudSnapshotSyncEnabled = false
    @AppStorage("defaultExportFormat") private var defaultExportFormat = "Markdown"
    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.openAI.rawValue
    @AppStorage("openAIModel") private var openAIModel = AIProvider.openAI.defaultModel
    @AppStorage("deepSeekModel") private var deepSeekModel = AIProvider.deepSeek.defaultModel
    @AppStorage("glmModel") private var glmModel = AIProvider.glm.defaultModel
    @State private var weReadAPIKey = KeychainService.loadWeReadAPIKey() ?? ""
    @State private var aiKeys: [AIProvider: String] = Dictionary(
        uniqueKeysWithValues: AIProvider.allCases.map { ($0, KeychainService.loadAPIKey(for: $0) ?? "") }
    )
    @State private var settingsMessage: String?
    @State private var dataActionMessage: String?
    @State private var cloudSyncMessage: String?
    @State private var isCloudSyncing = false
    @State private var cloudSnapshotDate: Date? = ICloudSyncService.latestSnapshotDate()
    @State private var backupCount: Int = AutoBackupService.listBackups().count
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                importSettingsSection
                aiSettingsSection
                exportSettingsSection
                cloudSyncSection
                dataManagementSection
            }
            .padding(24)
        }
    }

    // MARK: - 模块化设置区域
    
    private var importSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("导入与同步")
                        .font(.system(size: 15, weight: .semibold))
                    Text("配置微信读书同步和导入行为")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("启动时自动同步微信读书", isOn: $autoSyncOnLaunch)
                Toggle("导入时跳过重复笔记", isOn: $skipDuplicates)
                Toggle("导入后自动打开书籍", isOn: $autoOpenAfterImport)
                
                Divider().padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("微信读书 API Key")
                        .font(.system(size: 13, weight: .medium))
                    SecureField("wrk- 开头的 Key", text: $weReadAPIKey)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 8) {
                        Button {
                            pasteInto(&weReadAPIKey)
                        } label: {
                            Label("粘贴", systemImage: "doc.on.clipboard")
                        }
                        Button {
                            saveWeReadKey()
                        } label: {
                            Label("保存", systemImage: "key")
                        }
                        .disabled(weReadAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("清除") {
                            clearWeReadKey()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .premiumGlassPanel(cornerRadius: DesignSystem.CornerRadius.md, elevation: .sm)
    }
    
    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "brain")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 配置")
                        .font(.system(size: 15, weight: .semibold))
                    Text("设置 AI 供应商和 API Key")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Picker("默认供应商", selection: $aiProviderRaw) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.label).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                
                ForEach(AIProvider.allCases) { provider in
                    aiProviderPanel(provider)
                }
            }
            
            if let settingsMessage {
                Text(settingsMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .premiumGlassPanel(cornerRadius: DesignSystem.CornerRadius.md, elevation: .sm)
    }
    
    private func aiProviderPanel(_ provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(provider.label.prefix(1)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.primary)
                    )
                Text(provider.label)
                    .font(.system(size: 13, weight: .semibold))
            }
            
            SecureField(provider.keyPlaceholder, text: Binding(
                get: { aiKeys[provider] ?? "" },
                set: { aiKeys[provider] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            HStack(spacing: 8) {
                Text("模型")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField(provider.defaultModel, text: modelBinding(for: provider))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Spacer()
                Button {
                    pasteAIKey(for: provider)
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                }
                Button {
                    saveAIKey(for: provider)
                } label: {
                    Label("保存", systemImage: "key")
                }
                .disabled((aiKeys[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("清除") {
                    clearAIKey(for: provider)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(DesignSystem.Colors.surface.opacity(0.5))
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
    
    private var exportSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.success)
                VStack(alignment: .leading, spacing: 4) {
                    Text("导出设置")
                        .font(.system(size: 15, weight: .semibold))
                    Text("配置笔记导出格式和默认选项")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Text("默认导出格式")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $defaultExportFormat) {
                    Text("Markdown").tag("Markdown")
                    Text("TXT").tag("TXT")
                    Text("PDF").tag("PDF")
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
        }
        .padding(16)
        .premiumGlassPanel(cornerRadius: DesignSystem.CornerRadius.md, elevation: .sm)
    }
    
    private var cloudSyncSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "icloud")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("云端同步")
                        .font(.system(size: 15, weight: .semibold))
                    Text("通过 iCloud Drive 同步书摘库")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCloudSyncing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("启动时自动上传快照", isOn: $iCloudSnapshotSyncEnabled)
                
                HStack(spacing: 10) {
                    Button {
                        uploadToICloud()
                    } label: {
                        Label("上传", systemImage: "icloud.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCloudSyncing || appVM.allNotes.isEmpty)
                    
                    Button {
                        downloadFromICloud()
                    } label: {
                        Label("拉取", systemImage: "icloud.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCloudSyncing)
                    
                    Button {
                        openICloudFolder()
                    } label: {
                        Label("文件夹", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let cloudSnapshotDate {
                        Text("云端快照：\(cloudSnapshotDate.shortString)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("还没有云端快照")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    if let cloudSyncMessage {
                        Text(cloudSyncMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(cloudSyncMessage.contains("失败") ? .red : .secondary)
                    }
                }
            }
        }
        .padding(16)
        .premiumGlassPanel(cornerRadius: DesignSystem.CornerRadius.md, elevation: .sm)
    }
    
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据管理")
                        .font(.system(size: 15, weight: .semibold))
                    Text("备份、恢复和导出数据")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("数据库位置")
                        .font(.system(size: 12, weight: .medium))
                    if let storeURL = storeURL {
                        Text(storeURL.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    } else {
                        Text("由 SwiftData 自动管理")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    Button("导出全部") {
                        exportAllData()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("立即备份") {
                        backupDatabase()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("恢复备份") {
                        restoreDatabase()
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        appVM.selectedSidebarItem = .syncHistory
                    } label: {
                        Label("同步历史", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.bordered)
                }
                
                Toggle("自动备份（启动 + 每 6 小时）", isOn: $autoBackupEnabled)
                
                HStack(spacing: 4) {
                    Text("\(backupCount) 个备份文件，保留 7 天")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Button("打开备份目录") {
                        if let url = AutoBackupService.latestBackupURL()?.deletingLastPathComponent() {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
                }
            }
            
            if let dataActionMessage {
                Text(dataActionMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(dataActionMessage.contains("失败") ? .red : .secondary)
            }
        }
        .padding(16)
        .premiumGlassPanel(cornerRadius: DesignSystem.CornerRadius.md, elevation: .sm)
    }

    private var storeURL: URL? {
        modelContext.container.configurations.first?.url
    }

    private var modelContainer: ModelContainer { modelContext.container }

    private func exportAllData() {
        let markdown = MarkdownExporter().exportAllBooks(
            SafePersistence.fetch(modelContext, FetchDescriptor<Book>(), label: "exportAllData")
        )
        guard !markdown.isEmpty else {
            dataActionMessage = "没有可导出的笔记。"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "weread-notes-\(Date().shortString).md"
        panel.prompt = "导出"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try markdown.data(using: .utf8)?.write(to: url)
            dataActionMessage = "已导出到 \(url.lastPathComponent)。"
        } catch {
            dataActionMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func backupDatabase() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "weread-backup-\(Date().shortString).sqlite"
        panel.prompt = "备份"

        guard panel.runModal() == .OK, let destURL = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            if let sourceURL = storeURL {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                dataActionMessage = "数据库已备份到 \(destURL.lastPathComponent)。"
            }
            // 顺手做一次自动备份（如果用户还没启用），保证 listBackups 不空
            if !autoBackupEnabled {
                _ = try? AutoBackupService.backupNow(container: modelContainer)
                backupCount = AutoBackupService.listBackups().count
            }
        } catch {
            dataActionMessage = "备份失败：\(error.localizedDescription)"
        }
    }

    private func restoreDatabase() {
        guard let destURL = storeURL else {
            dataActionMessage = "找不到数据库文件位置。"
            return
        }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.data]
        panel.message = "选择之前备份的 .sqlite 文件"
        panel.prompt = "恢复"

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        do {
            SafePersistence.save(modelContext, label: "restoreDatabase")
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            dataActionMessage = "数据库已恢复，请重启应用以加载数据。"
        } catch {
            dataActionMessage = "恢复失败：\(error.localizedDescription)"
        }
    }

    private func uploadToICloud() {
        isCloudSyncing = true
        do {
            let summary = try ICloudSyncService.upload(books: appVM.books)
            cloudSnapshotDate = ICloudSyncService.latestSnapshotDate()
            cloudSyncMessage = "已上传 \(summary.notesCreated) 条笔记到 iCloud。"
        } catch {
            cloudSyncMessage = "上传失败：\(error.localizedDescription)"
        }
        isCloudSyncing = false
    }

    private func downloadFromICloud() {
        isCloudSyncing = true
        Task {
            do {
                let summary = try await ICloudSyncService.download(container: modelContainer)
                appVM.refreshBooks(context: modelContext)
                cloudSnapshotDate = ICloudSyncService.latestSnapshotDate()
                cloudSyncMessage = summary.message
            } catch {
                cloudSyncMessage = "拉取失败：\(error.localizedDescription)"
            }
            isCloudSyncing = false
        }
    }

    private func openICloudFolder() {
        do {
            NSWorkspace.shared.open(try ICloudSyncService.cloudDirectory())
        } catch {
            cloudSyncMessage = "打开失败：\(error.localizedDescription)"
        }
    }

    private func pasteInto(_ value: inout String) {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            settingsMessage = "剪贴板里没有可粘贴的文本。"
            return
        }
        value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveWeReadKey() {
        do {
            try KeychainService.saveWeReadAPIKey(weReadAPIKey.trimmingCharacters(in: .whitespacesAndNewlines))
            settingsMessage = "微信读书 Key 已保存。"
        } catch {
            settingsMessage = error.localizedDescription
        }
    }

    private func clearWeReadKey() {
        do {
            try KeychainService.deleteWeReadAPIKey()
            weReadAPIKey = ""
            settingsMessage = "微信读书 Key 已清除。"
        } catch {
            settingsMessage = error.localizedDescription
        }
    }

    private func pasteAIKey(for provider: AIProvider) {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            settingsMessage = "剪贴板里没有可粘贴的文本。"
            return
        }
        aiKeys[provider] = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveAIKey(for provider: AIProvider) {
        do {
            try KeychainService.saveAPIKey((aiKeys[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines), for: provider)
            settingsMessage = "\(provider.label) Key 已保存。"
        } catch {
            settingsMessage = error.localizedDescription
        }
    }

    private func clearAIKey(for provider: AIProvider) {
        do {
            try KeychainService.deleteAPIKey(for: provider)
            aiKeys[provider] = ""
            settingsMessage = "\(provider.label) Key 已清除。"
        } catch {
            settingsMessage = error.localizedDescription
        }
    }

    private func modelBinding(for provider: AIProvider) -> Binding<String> {
        Binding(
            get: {
                switch provider {
                case .openAI: return openAIModel
                case .deepSeek: return deepSeekModel
                case .glm: return glmModel
                }
            },
            set: { value in
                switch provider {
                case .openAI: openAIModel = value
                case .deepSeek: deepSeekModel = value
                case .glm: glmModel = value
                }
            }
        )
    }
}
