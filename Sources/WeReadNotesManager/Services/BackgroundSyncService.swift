import Foundation
import SwiftData
import os
import UserNotifications

/// 后台定时同步服务（Feature 10）。
///
/// macOS 上 `BGTaskScheduler` 需要 App Extension 才能真正后台运行；
/// 在主 App 进程内只做每日 21:00 本地通知，提示用户手动同步。
/// 不在启动时自动拉取微信读书，避免影响用户直接进入书摘阅读。
///
/// 未来如果想做真正的后台同步，需要把同步逻辑搬到 App Extension target 里。
@MainActor
final class BackgroundSyncService {
    static let shared = BackgroundSyncService()

    nonisolated private static let logger = Logger(subsystem: "com.weread.notesmanager", category: "backgroundSync")
    private let reminderHour = 21

    private init() {}

    /// 安装后台同步：在 App 启动后调用一次。
    func install(container: ModelContainer, context: ModelContext) {
        scheduleNextSync()
    }

    /// 立即触发同步（在 UI 已经启动完成后调用）。
    func runOnce(container: ModelContainer, context: ModelContext) async {
        guard let key = KeychainService.loadWeReadAPIKey(), !key.isEmpty else {
            Self.logger.info("未配置 API Key，跳过后台同步")
            return
        }
        Self.logger.info("开始后台同步微信读书")
        do {
            let defaults = UserDefaults.standard
            let filterLowNoteBooks = defaults.object(forKey: "filterLowNoteBooksOnImport") as? Bool ?? true
            let minNotesPerBook = defaults.object(forKey: "minNotesPerImportedBook") as? Int ?? 5
            let skipDuplicates = defaults.object(forKey: "skipDuplicates") as? Bool ?? true
            let coordinator = ImportCoordinator(
                container: container,
                skipDuplicates: skipDuplicates,
                minNotesPerBook: filterLowNoteBooks ? minNotesPerBook : 0
            )
            let summary = try await coordinator.syncWeRead(apiKey: key) { _ in
                // 忽略进度更新（后台同步无 UI）
            }
            Self.logger.info("后台同步完成，新增 \(summary.notesCreated) 条，跳过 \(summary.duplicatesSkipped) 条")
        } catch is CancellationError {
            Self.logger.info("后台同步被取消")
        } catch {
            AppLog.error("后台同步失败", error: error, category: .network)
        }
    }

    /// 调度下一次"提醒用户同步"的本地通知。
    func scheduleNextSync() {
        let center = UNUserNotificationCenter.current()
        
        // 先检查当前授权状态
        center.getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.scheduleDailyReminder()
                case .notDetermined:
                    // 请求授权
                    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        Task { @MainActor in
                            if granted {
                                self.scheduleDailyReminder()
                            } else {
                                Self.logger.info("用户未授权通知，跳过后台提醒")
                            }
                        }
                    }
                case .denied:
                    Self.logger.info("用户已拒绝通知权限，跳过后台提醒")
                @unknown default:
                    break
                }
            }
        }
    }

    private func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])

        let content = UNMutableNotificationContent()
        content.title = "微信读书同步提醒"
        content.body = "点击让 树懒书摘 拉取最新的划线和想法。"
        content.sound = .default

        var trigger = DateComponents()
        trigger.hour = reminderHour
        trigger.minute = 0
        let dailyTrigger = UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)

        let request = UNNotificationRequest(
            identifier: Self.reminderID,
            content: content,
            trigger: dailyTrigger
        )

        center.add(request) { error in
            if let error {
                AppLog.error("调度后台提醒失败", error: error, category: .general)
            }
        }
    }

    private static let reminderID = "com.weread.notesmanager.daily-sync-reminder"
}
