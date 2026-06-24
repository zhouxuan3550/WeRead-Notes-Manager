import Foundation
import SwiftData
import os

/// 自动备份服务：定期将 SwiftData 数据库复制到 Application Support/Backups/。
///
/// 策略：
/// - 启动时（onAppear / app launch）立即触发一次
/// - 每次保存时检查距上次备份时间，超过 6 小时再备份
/// - 保留最近 7 天的备份，滚动覆盖
///
/// 不使用 BGTaskScheduler（macOS 上需要 App Extension 才能跑），
/// 改为"惰性 + 时机"策略：启动后首次交互前完成备份。
enum AutoBackupService {
    private static let logger = Logger(subsystem: "com.weread.notesmanager", category: "backup")
    private static let retentionDays: Int = 7
    private static let intervalBetweenBackups: TimeInterval = 6 * 3600
    private static let lastBackupKey = "AutoBackupService.lastBackupAt"

    /// 触发备份（如果距上次备份超过阈值）。
    static func runIfNeeded(container: ModelContainer) {
        let now = Date()
        if let last = UserDefaults.standard.object(forKey: lastBackupKey) as? Date,
           now.timeIntervalSince(last) < intervalBetweenBackups {
            return
        }
        do {
            try performBackup(container: container)
            UserDefaults.standard.set(now, forKey: lastBackupKey)
        } catch {
            AppLog.error("自动备份失败", error: error, category: .general)
        }
    }

    /// 强制立即备份一次（用户点击"立即备份"时）。
    @discardableResult
    static func backupNow(container: ModelContainer) throws -> URL? {
        try performBackup(container: container)
        UserDefaults.standard.set(Date(), forKey: lastBackupKey)
        return latestBackupURL()
    }

    /// 清理过期备份。
    static func purgeExpired() {
        let fm = FileManager.default
        guard let dir = backupDirectoryURL() else { return }
        guard let files = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)
        for file in files where file.pathExtension == "sqlite" {
            let modDate = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if modDate < cutoff {
                try? fm.removeItem(at: file)
                logger.info("删除过期备份 \(file.lastPathComponent, privacy: .public)")
            }
        }
    }

    /// 列出所有备份文件，按时间倒序。
    static func listBackups() -> [URL] {
        let fm = FileManager.default
        guard let dir = backupDirectoryURL(),
              let files = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "sqlite" }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
    }

    static func latestBackupURL() -> URL? {
        listBackups().first
    }

    // MARK: - Private

    private static func performBackup(container: ModelContainer) throws {
        // 1. 找到源数据库文件
        guard let sourceURL = container.configurations.first?.url else {
            throw AutoBackupError.noDatabaseConfigured
        }
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw AutoBackupError.databaseFileNotFound(sourceURL.path)
        }

        // 2. 准备目标目录
        let dir = try ensureBackupDirectory()

        // 3. 触发 SwiftData flush（在 actor 内做更安全，但 container 已有 mainContext，
        //    我们用一个临时 context 让它在落盘前主动 save）
        try flushPendingChanges(container: container)

        // 4. 复制文件
        let stamp = DateFormatter.fileDayStamp.string(from: Date())
        let destURL = dir.appendingPathComponent("weread-backup-\(stamp)-\(Int.random(in: 1000...9999)).sqlite")
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        logger.info("已备份到 \(destURL.lastPathComponent, privacy: .public)")
    }

    /// 强制把内存中的 pending changes 落盘。
    private static func flushPendingChanges(container: ModelContainer) throws {
        // 临时新建一个 context 用 mainContext 的 container，但不持有 mainContext 锁。
        let context = ModelContext(container)
        try context.save()
    }

    private static func backupDirectoryURL() -> URL? {
        let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base?.appendingPathComponent("WeReadNotesManager/Backups", isDirectory: true)
    }

    @discardableResult
    private static func ensureBackupDirectory() throws -> URL {
        guard let dir = backupDirectoryURL() else {
            throw AutoBackupError.cannotResolveBackupDirectory
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

enum AutoBackupError: LocalizedError {
    case noDatabaseConfigured
    case databaseFileNotFound(String)
    case cannotResolveBackupDirectory

    var errorDescription: String? {
        switch self {
        case .noDatabaseConfigured:
            return "找不到数据库配置。"
        case .databaseFileNotFound(let path):
            return "数据库文件不存在：\(path)"
        case .cannotResolveBackupDirectory:
            return "无法解析备份目录路径。"
        }
    }
}