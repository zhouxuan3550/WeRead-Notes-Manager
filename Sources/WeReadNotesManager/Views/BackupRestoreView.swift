import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

// MARK: - 备份与恢复 UI
//
// 提供：
// - 立即备份按钮
// - 备份历史列表（可还原）
// - 自定义导出位置
// - 跨设备导入/导出（zip 打包）
// - 自动备份开关

struct BackupRestoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.themePalette) private var palette

    @State private var backups: [URL] = []
    @State private var selectedBackup: URL?
    @State private var isBackingUp = false
    @State private var statusMessage: String?
    @State private var showRestoreConfirm = false
    @State private var showExportSheet = false

    @AppStorage("autoBackupEnabled") private var autoBackupEnabled = true
    @AppStorage("backupDirectory") private var backupDirectory: String = ""

    private var modelContainer: ModelContainer { modelContext.container }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    autoBackupSection
                    backupNowSection
                    backupHistorySection
                    exportImportSection
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(statusMessageColor)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 6).fill(statusMessageColor.opacity(0.10)))
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 640, height: 520)
        .onAppear {
            refresh()
        }
        .alert("确认恢复？", isPresented: $showRestoreConfirm) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                performRestore()
            }
        } message: {
            Text("将从备份 \(selectedBackup?.lastPathComponent ?? "") 恢复数据库。当前所有笔记会被备份覆盖。建议先备份一次。")
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text("备份与恢复")
                .font(.headline)
            Spacer()
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    // MARK: - 自动备份设置

    private var autoBackupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("自动备份")
                        .font(.system(size: 14, weight: .semibold))
                    Text("每 6 小时自动备份一次，保留最近 7 天")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $autoBackupEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface.opacity(0.5)))

            HStack {
                Text("存储位置")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Text(backupDirectory.isEmpty ? AutoBackupService.defaultDirectoryDescription : backupDirectory)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("更改...") {
                    chooseBackupDirectory()
                }
                .flatActionButton(height: 32)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - 立即备份

    private var backupNowSection: some View {
        Button {
            backupNow()
        } label: {
            HStack {
                if isBackingUp {
                    ProgressView().controlSize(.small)
                    Text("备份中...")
                } else {
                    Image(systemName: "tray.and.arrow.down.fill")
                    Text("立即备份")
                        .fontWeight(.semibold)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.accent.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(palette.accent.opacity(0.5), lineWidth: 1)
            )
            .foregroundStyle(palette.accent)
        }
        .buttonStyle(.plain)
        .disabled(isBackingUp)
    }

    // MARK: - 备份历史

    private var backupHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备份历史")
                .font(.system(size: 14, weight: .semibold))

            if backups.isEmpty {
                HStack {
                    Image(systemName: "tray")
                    Text("暂无备份")
                        .font(.caption)
                }
                .foregroundStyle(palette.textTertiary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface.opacity(0.3)))
            } else {
                VStack(spacing: 4) {
                    ForEach(backups, id: \.self) { url in
                        backupRow(url)
                    }
                }
            }
        }
    }

    private func backupRow(_ url: URL) -> some View {
        let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = ByteCountFormatter().string(fromByteCount: Int64(attrs?.fileSize ?? 0))
        let date = attrs?.contentModificationDate ?? .now
        let isSelected = selectedBackup == url

        return HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .foregroundStyle(isSelected ? palette.accent : palette.textSecondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text("\(date.shortString) · \(size)")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textTertiary)
            }

            Spacer()

            Button {
                selectedBackup = url
                showRestoreConfirm = true
            } label: {
                Label("恢复", systemImage: "arrow.uturn.backward")
            }
            .flatActionButton(.accent, height: 32)
            .controlSize(.small)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? palette.accent.opacity(0.10) : palette.surface.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? palette.accent : palette.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - 导出导入（zip 跨设备）

    private var exportImportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("跨设备迁移")
                .font(.system(size: 14, weight: .semibold))

            HStack(spacing: 10) {
                Button {
                    exportZip()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up.on.square")
                            .font(.system(size: 20))
                        Text("导出全部")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                }
                .flatActionButton(height: 32)

                Button {
                    importBackupZip()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 20))
                        Text("导入备份包")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                }
                .flatActionButton(height: 32)
            }
        }
    }

    // MARK: - 动作

    private func refresh() {
        backups = AutoBackupService.listBackups()
    }

    private func backupNow() {
        isBackingUp = true
        statusMessage = nil
        Task {
            do {
                if let url = try AutoBackupService.backupNow(container: modelContainer) {
                    await MainActor.run {
                        statusMessage = "✅ 备份成功：\(url.lastPathComponent)"
                        isBackingUp = false
                        refresh()
                    }
                } else {
                    await MainActor.run {
                        statusMessage = "⚠️ 备份未生成"
                        isBackingUp = false
                    }
                }
            } catch {
                await MainActor.run {
                    statusMessage = "❌ 备份失败：\(error.localizedDescription)"
                    isBackingUp = false
                }
            }
        }
    }

    private func performRestore() {
        guard let url = selectedBackup else { return }
        statusMessage = nil
        Task {
            do {
                try AutoBackupService.restore(from: url, container: modelContainer)
                await MainActor.run {
                    appVM.refreshBooks(context: modelContext)
                    statusMessage = "✅ 恢复成功，请重新打开 App"
                }
            } catch {
                await MainActor.run {
                    statusMessage = "❌ 恢复失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func chooseBackupDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            backupDirectory = url.path
        }
    }

    private func exportZip() {
        let panel = NSSavePanel()
        if let type = UTType(filenameExtension: "wread") {
            panel.allowedContentTypes = [type]
        }
        panel.nameFieldStringValue = "树懒书摘-备份-\(Date().shortString).wread"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try BackupPackage.export(to: url, container: modelContainer)
                statusMessage = "✅ 已导出到 \(url.lastPathComponent)"
            } catch {
                statusMessage = "❌ 导出失败：\(error.localizedDescription)"
            }
        }
    }

    private func importBackupZip() {
        let panel = NSOpenPanel()
        if let type = UTType(filenameExtension: "wread") {
            panel.allowedContentTypes = [type]
        }
        panel.allowsMultipleSelection = false
        panel.prompt = "导入"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try BackupPackage.importFromZip(from: url, container: modelContainer)
                appVM.refreshBooks(context: modelContext)
                statusMessage = "✅ 已导入，请重启 App"
            } catch {
                statusMessage = "❌ 导入失败：\(error.localizedDescription)"
            }
        }
    }

    private var statusMessageColor: Color {
        guard let msg = statusMessage else { return palette.textPrimary }
        if msg.contains("✅") { return palette.success }
        if msg.contains("❌") { return palette.error }
        return palette.warning
    }
}

// MARK: - AutoBackupService 扩展

extension AutoBackupService {
    static var defaultDirectoryDescription: String {
        guard let dir = backupDirectoryURL() else { return "未配置" }
        return dir.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    static func restore(from url: URL, container: ModelContainer) throws {
        let fm = FileManager.default
        // 先备份当前
        _ = try? backupNow(container: container)
        // 找到当前数据库位置
        let storeURL = container.configurations.first?.url
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("default.store")
        if fm.fileExists(atPath: storeURL.path) {
            try fm.removeItem(at: storeURL)
        }
        try fm.copyItem(at: url, to: storeURL)
    }
}

// MARK: - 备份包（zip 格式）

enum BackupPackage {
    static func export(to url: URL, container: ModelContainer) throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("wread-export-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 复制数据库
        if let storeURL = container.configurations.first?.url {
            try fm.copyItem(at: storeURL, to: tempDir.appendingPathComponent("store.sqlite"))
        }

        // 复制附件
        let attachDir = ImageAttachmentService.attachmentsDirectory
        let attachTarget = tempDir.appendingPathComponent("attachments")
        if fm.fileExists(atPath: attachDir.path) {
            try fm.copyItem(at: attachDir, to: attachTarget)
        }

        // 打包成 zip
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var copyError: Error?
        var success = false
        coordinator.coordinate(readingItemAt: tempDir, options: [.forUploading], error: &coordError) { zipURL in
            do {
                try fm.copyItemReplacingExisting(at: zipURL, to: url)
                success = true
            } catch {
                copyError = error
            }
        }
        try? fm.removeItem(at: tempDir)

        if let err = coordError {
            throw err
        }
        if let copyError {
            throw copyError
        }
        if !success {
            throw NSError(domain: "BackupPackage", code: -1, userInfo: [NSLocalizedDescriptionKey: "打包失败"])
        }
    }

    static func importFromZip(from url: URL, container: ModelContainer) throws {
        let fm = FileManager.default
        let extractDir = fm.temporaryDirectory.appendingPathComponent("wread-import-\(UUID().uuidString)")
        try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)

        // 解压 zip
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var unzipError: Error?
        coordinator.coordinate(readingItemAt: url, options: [.forUploading], error: &coordError) { tempZip in
            do {
                try fm.unzipArchive(at: tempZip, to: extractDir)
            } catch {
                unzipError = error
            }
        }
        if let err = coordError { throw err }
        if let unzipError { throw unzipError }

        // 复制数据库
        let storeSource = extractDir.appendingPathComponent("store.sqlite")
        if fm.fileExists(atPath: storeSource.path) {
            if let storeDest = container.configurations.first?.url {
                _ = try? AutoBackupService.backupNow(container: container)
                try fm.copyItemReplacingExisting(at: storeSource, to: storeDest)
            }
        }

        // 复制附件
        let attachSource = extractDir.appendingPathComponent("attachments")
        if fm.fileExists(atPath: attachSource.path) {
            let attachDest = ImageAttachmentService.attachmentsDirectory
            try? fm.removeItem(at: attachDest)
            try fm.copyItem(at: attachSource, to: attachDest)
        }

        try? fm.removeItem(at: extractDir)
    }
}

private extension FileManager {
    func copyItemReplacingExisting(at sourceURL: URL, to destinationURL: URL) throws {
        if fileExists(atPath: destinationURL.path) {
            try removeItem(at: destinationURL)
        }
        try copyItem(at: sourceURL, to: destinationURL)
    }

    func unzipArchive(at archiveURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "BackupPackage",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "解压备份包失败"]
            )
        }
    }
}
