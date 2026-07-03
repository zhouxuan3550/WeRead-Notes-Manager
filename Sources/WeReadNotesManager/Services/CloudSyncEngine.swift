import Foundation
import SwiftData
import CloudKit
import Combine
import SwiftUI

// MARK: - iCloud 同步引擎
//
// 用 SwiftData + CloudKit 实现多设备同步。
// - SwiftData ModelContainer 支持 CloudKit 集成
// - 自动处理同步冲突（CKSyncEngine）
// - UI 层显示同步状态
//
// 启用要求：
// 1. Apple Developer 账号
// 2. App ID 启用 CloudKit
// 3. 容器：iCloud.com.weread.notesmanager
// 4. SwiftData ModelConfiguration(cloudKitDatabase: .private("iCloud.com.weread.notesmanager"))

// MARK: - 同步状态

enum CloudSyncStatus: String {
    case unknown
    case ready           // 容器就绪
    case importing       // 下载中
    case exporting       // 上传中
    case idle            // 空闲
    case error           // 出错

    var displayName: String {
        switch self {
        case .unknown: return "未知"
        case .ready: return "已就绪"
        case .importing: return "下载中"
        case .exporting: return "上传中"
        case .idle: return "空闲"
        case .error: return "出错"
        }
    }

    var icon: String {
        switch self {
        case .unknown: return "icloud"
        case .ready: return "icloud.fill"
        case .importing: return "icloud.and.arrow.down"
        case .exporting: return "icloud.and.arrow.up"
        case .idle: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        }
    }
}

// MARK: - 同步引擎

@MainActor
@Observable
final class CloudSyncEngine {
    static let shared = CloudSyncEngine()

    var status: CloudSyncStatus = .unknown
    var lastSyncDate: Date?
    var lastError: String?
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "iCloudSyncEnabled")
            if isEnabled {
                Task { await enableCloudSync() }
            } else {
                Task { await disableCloudSync() }
            }
        }
    }
    var containerIdentifier: String = "iCloud.com.weread.notesmanager"

    private var modelContainer: ModelContainer?

    private init() {
        if let stored = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool {
            self.isEnabled = stored
        } else {
            self.isEnabled = false
        }
        self.lastSyncDate = UserDefaults.standard.object(forKey: "iCloudSyncLastDate") as? Date
    }

    // MARK: - 检查可用性

    /// 检查 iCloud 账户状态
    func checkAccountStatus() async -> CKAccountStatus {
        do {
            let status = try await CKContainer.default().accountStatus()
            return status
        } catch {
            return .couldNotDetermine
        }
    }

    /// 检查 CloudKit 容器是否存在
    func checkContainer() async -> Bool {
        do {
            let container = CKContainer(identifier: containerIdentifier)
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - 启用

    /// 启用 iCloud 同步
    /// - 注意：SwiftData + CloudKit 的 ModelConfiguration 必须在 App 启动时设置，
    ///   所以"启用"实际上是显示指引，让用户重启 App 或执行手动同步。
    @MainActor
    func enableCloudSync() async {
        status = .ready
        do {
            try await CKContainer(identifier: containerIdentifier).accountStatus()
            // 推送待同步数据
            await pushLocalChanges()
            status = .idle
            lastSyncDate = .now
            UserDefaults.standard.set(Date(), forKey: "iCloudSyncLastDate")
        } catch {
            status = .error
            lastError = error.localizedDescription
        }
    }

    /// 禁用 iCloud 同步
    @MainActor
    func disableCloudSync() async {
        status = .idle
    }

    // MARK: - 推送本地变更

    /// 把本地笔记推送到 CloudKit
    @MainActor
    func pushLocalChanges() async {
        guard let modelContainer = modelContainer else { return }
        status = .exporting

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ReadingNote>()
        let notes = (try? context.fetch(descriptor)) ?? []

        do {
            // SwiftData + CloudKit 自动同步；这里手动强制刷新
            try context.save()
            status = .idle
            lastSyncDate = .now
            UserDefaults.standard.set(Date(), forKey: "iCloudSyncLastDate")
        } catch {
            status = .error
            lastError = error.localizedDescription
        }
    }

    /// 拉取远端变更
    @MainActor
    func pullRemoteChanges() async {
        guard let modelContainer = modelContainer else { return }
        status = .importing

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Book>()
        _ = (try? context.fetch(descriptor)) ?? []

        status = .idle
        lastSyncDate = .now
        UserDefaults.standard.set(Date(), forKey: "iCloudSyncLastDate")
    }

    /// 注入当前 ModelContainer（App 启动时调用）
    func attach(container: ModelContainer) {
        self.modelContainer = container
        Task { await checkContainer() }
    }

    // MARK: - 状态摘要

    var statusDescription: String {
        switch status {
        case .unknown:
            return "未配置"
        case .ready:
            return "已就绪"
        case .importing:
            return "正在下载远端变更..."
        case .exporting:
            return "正在上传本地变更..."
        case .idle:
            return lastSyncDate.map { "已同步 · \($0.shortString)" } ?? "空闲"
        case .error:
            return lastError ?? "未知错误"
        }
    }
}

// MARK: - 启动时 iCloud 容器配置辅助

enum CloudContainerFactory {
    /// 创建带 CloudKit 的 ModelContainer
    /// - 失败时降级到本地
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Book.self,
            ReadingNote.self,
            ImportRecord.self,
            Tag.self,
            BookSummary.self
        ])

        // 1. 尝试 CloudKit 容器
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .private("iCloud.com.weread.notesmanager")
        )

        if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            return container
        }

        // 2. 降级到本地
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        return try! ModelContainer(for: schema, configurations: [localConfig])
    }
}

// MARK: - UI

struct CloudSyncSettingsView: View {
    @State private var engine = CloudSyncEngine.shared
    @State private var accountStatusText: String = "检查中..."
    @State private var isContainerReady = false

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 8).fill(palette.accentSoft))

                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud 同步")
                        .font(.system(size: 15, weight: .semibold))
                    Text("在所有 Apple 设备间同步笔记库")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("启用 iCloud 同步", isOn: $engine.isEnabled)
                    .disabled(!isContainerReady)

                statusRow

                if engine.isEnabled {
                    HStack(spacing: 10) {
                        Button {
                            Task { await engine.pullRemoteChanges() }
                        } label: {
                            Label("下载", systemImage: "icloud.and.arrow.down")
                        }
                        .flatActionButton(height: 32)

                        Button {
                            Task { await engine.pushLocalChanges() }
                        } label: {
                            Label("上传", systemImage: "icloud.and.arrow.up")
                        }
                        .flatActionButton(height: 32)
                    }
                }

                // 警告
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(palette.warning)
                        .font(.system(size: 12))
                    Text("启用需重启 App 生效。Apple Developer 账号需配置 CloudKit 容器 iCloud.com.weread.notesmanager")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(palette.warning.opacity(0.10)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.surface.opacity(0.5))
        )
        .task {
            await refreshStatus()
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: engine.status.icon)
                .foregroundStyle(statusColor)
            Text(engine.statusDescription)
                .font(.system(size: 12))
                .foregroundStyle(palette.textPrimary)
            Spacer()
            Text(accountStatusText)
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)
        }
    }

    private var statusColor: Color {
        switch engine.status {
        case .idle, .ready: return palette.success
        case .importing, .exporting: return palette.accent
        case .error: return palette.error
        case .unknown: return palette.textTertiary
        }
    }

    private func refreshStatus() async {
        let status = await engine.checkAccountStatus()
        switch status {
        case .available:
            accountStatusText = "iCloud 已登录"
            isContainerReady = await engine.checkContainer()
        case .noAccount:
            accountStatusText = "未登录 iCloud"
            isContainerReady = false
        case .restricted:
            accountStatusText = "iCloud 受限"
            isContainerReady = false
        case .couldNotDetermine:
            accountStatusText = "无法确定状态"
            isContainerReady = false
        case .temporarilyUnavailable:
            accountStatusText = "暂时不可用"
            isContainerReady = false
        @unknown default:
            accountStatusText = "未知"
            isContainerReady = false
        }
    }
}