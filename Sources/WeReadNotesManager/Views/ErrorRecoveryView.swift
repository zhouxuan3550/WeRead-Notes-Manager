import SwiftUI

// MARK: - 错误恢复向导
//
// 当同步、导入、AI 调用失败时，给用户：
// 1. 错误原因分析（不是只显示 "出错了"）
// 2. 可执行的修复步骤
// 3. 一键跳转到对应设置

enum ErrorKind: String {
    case networkOffline       // 网络断开
    case apiKeyInvalid        // API Key 无效
    case apiKeyMissing        // 未配置 API Key
    case apiQuotaExceeded     // 配额用完
    case serverTimeout        // 服务超时
    case rateLimited          // 频率限制
    case parseError           // 数据解析失败
    case storageFull          // 磁盘空间不足
    case fileCorrupt          // 文件损坏
    case unknown              // 未知

    var icon: String {
        switch self {
        case .networkOffline: return "wifi.slash"
        case .apiKeyInvalid: return "key.slash"
        case .apiKeyMissing: return "key"
        case .apiQuotaExceeded: return "exclamationmark.octagon"
        case .serverTimeout: return "clock.badge.exclamationmark"
        case .rateLimited: return "speedometer"
        case .parseError: return "doc.questionmark"
        case .storageFull: return "internaldrive.fill"
        case .fileCorrupt: return "exclamationmark.triangle"
        case .unknown: return "questionmark.circle"
        }
    }

    var severity: Int {
        switch self {
        case .networkOffline, .serverTimeout: return 1  // 警告
        case .apiKeyMissing, .parseError: return 2       // 错误
        case .apiKeyInvalid, .apiQuotaExceeded, .rateLimited, .storageFull, .fileCorrupt: return 3  // 严重
        case .unknown: return 1
        }
    }
}

struct ErrorAnalysis {
    let kind: ErrorKind
    let title: String
    let cause: String
    let steps: [RecoveryStep]
    let canAutoFix: Bool

    struct RecoveryStep: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let action: RecoveryAction?

        enum RecoveryAction {
            case openSettings
            case openImport
            case retry
            case openURL(URL)
            case openAIKeySettings
            case showBackupRestore
        }
    }
}

// MARK: - 错误分析器

enum ErrorAnalyzer {
    static func analyze(_ error: Error, context: String = "") -> ErrorAnalysis {
        let nsError = error as NSError

        // 1. 网络错误
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return networkOffline()
            case NSURLErrorTimedOut:
                return serverTimeout()
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                return serverTimeout()
            case 429:
                return rateLimited()
            default:
                return unknown(error)
            }
        }

        // 2. AI Key 相关
        let message = nsError.localizedDescription.lowercased()
        if message.contains("api key") || message.contains("unauthorized") || message.contains("invalid_api_key") || nsError.code == 401 {
            return apiKeyInvalid()
        }
        if message.contains("quota") || message.contains("insufficient") || message.contains("billing") || nsError.code == 402 {
            return apiQuotaExceeded()
        }
        if message.contains("rate limit") || message.contains("too many") {
            return rateLimited()
        }

        // 3. 文件错误
        if message.contains("no space") || message.contains("disk full") {
            return storageFull()
        }
        if message.contains("corrupt") || message.contains("invalid data") || message.contains("malformed") {
            return fileCorrupt()
        }

        // 4. 解析错误
        if context.contains("import") || context.contains("parse") {
            return parseError(error)
        }

        return unknown(error)
    }

    // MARK: - 预置场景

    static func networkOffline() -> ErrorAnalysis {
        ErrorAnalysis(
            kind: .networkOffline,
            title: "网络连接失败",
            cause: "设备当前没有连接到互联网。",
            steps: [
                .init(icon: "wifi", text: "检查 Wi-Fi 或网线是否正常", action: nil),
                .init(icon: "arrow.clockwise", text: "稍后自动重试或点击「重试」", action: .retry),
                .init(icon: "gearshape", text: "如使用代理，请在系统设置里配置", action: .openSettings)
            ],
            canAutoFix: true
        )
    }

    static func serverTimeout() -> ErrorAnalysis {
        ErrorAnalysis(
            kind: .serverTimeout,
            title: "服务超时",
            cause: "服务器响应过慢或暂时不可用。",
            steps: [
                .init(icon: "clock", text: "等待 30 秒后重试", action: nil),
                .init(icon: "arrow.clockwise", text: "点击「重试」按钮", action: .retry)
            ],
            canAutoFix: true
        )
    }

    static func apiKeyMissing() -> ErrorAnalysis {
        ErrorAnalysis(
            kind: .apiKeyMissing,
            title: "未配置 API Key",
            cause: "AI 功能需要先配置 API Key 才能使用。",
            steps: [
                .init(icon: "key", text: "前往设置 → AI 配置", action: .openAIKeySettings),
                .init(icon: "doc.on.clipboard", text: "粘贴你的 API Key 并保存", action: nil)
            ],
            canAutoFix: false
        )
    }

    static func apiKeyInvalid() -> ErrorAnalysis {
        ErrorAnalysis(
            kind: .apiKeyInvalid,
            title: "API Key 无效",
            cause: "可能是 Key 已过期、被吊销或填错。",
            steps: [
                .init(icon: "key", text: "检查 API Key 是否完整复制（没有前后空格）", action: nil),
                .init(icon: "arrow.right.square", text: "前往 API 提供商后台重新生成 Key", action: nil),
                .init(icon: "key", text: "在设置 → AI 配置 里更新 Key", action: .openAIKeySettings)
            ],
            canAutoFix: false
        )
    }

    static func apiQuotaExceeded() -> ErrorAnalysis {
        ErrorAnalysis(
            kind: .apiQuotaExceeded,
            title: "API 配额用完",
            cause: "账户余额不足或本月配额已用尽。",
            steps: [
                .init(icon: "creditcard", text: "前往 OpenAI / DeepSeek / GLM 后台充值", action: nil),
                .init(icon: "arrow.triangle.swap", text: "切换到其他 AI 提供商", action: .openAIKeySettings)
            ],
            canAutoFix: false
        )
    }

    static func rateLimited() -> ErrorAnalysis {
        ErrorAnalysis(
            kind: .rateLimited,
            title: "请求过于频繁",
            cause: "短时间内发送了太多请求，触发了频率限制。",
            steps: [
                .init(icon: "hourglass", text: "等待 1-5 分钟后重试", action: nil),
                .init(icon: "arrow.clockwise", text: "点击「重试」", action: .retry)
            ],
            canAutoFix: true
        )
    }

    static func parseError(_ error: Error) -> ErrorAnalysis {
        ErrorAnalysis(
            kind: .parseError,
            title: "文件解析失败",
            cause: "文件格式可能不符合预期，或包含特殊字符。",
            steps: [
                .init(icon: "doc.text.magnifyingglass", text: "确认文件是 TXT / Markdown 格式", action: nil),
                .init(icon: "arrow.up.doc", text: "尝试用「通用文件」方式导入", action: .openImport),
                .init(icon: "exclamationmark.bubble", text: "附上文件提交 Issue：GitHub 项目页", action: nil)
            ],
            canAutoFix: false
        )
    }

    static func storageFull() -> ErrorAnalysis {
        ErrorAnalysis(
            kind: .storageFull,
            title: "磁盘空间不足",
            cause: "Mac 剩余空间不够保存新笔记。",
            steps: [
                .init(icon: "externaldrive.badge.checkmark", text: "清理不需要的文件", action: nil),
                .init(icon: "trash", text: "清空废纸篓", action: nil),
                .init(icon: "tray.and.arrow.up", text: "导出备份后删除旧数据", action: .showBackupRestore)
            ],
            canAutoFix: false
        )
    }

    static func fileCorrupt() -> ErrorAnalysis {
        ErrorAnalysis(
            kind: .fileCorrupt,
            title: "文件损坏",
            cause: "数据库或备份文件可能已损坏。",
            steps: [
                .init(icon: "tray.and.arrow.down", text: "从最近的备份恢复", action: .showBackupRestore),
                .init(icon: "questionmark.circle", text: "如持续出现，请联系开发者", action: nil)
            ],
            canAutoFix: true
        )
    }

    static func unknown(_ error: Error) -> ErrorAnalysis {
        ErrorAnalysis(
            kind: .unknown,
            title: "未知错误",
            cause: error.localizedDescription,
            steps: [
                .init(icon: "arrow.clockwise", text: "重试一次", action: .retry),
                .init(icon: "exclamationmark.bubble", text: "附上错误信息反馈给开发者", action: nil)
            ],
            canAutoFix: true
        )
    }
}

// MARK: - 错误恢复 UI

struct ErrorRecoveryView: View {
    let analysis: ErrorAnalysis
    let onRetry: (() -> Void)?

    @Environment(\.themePalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var expandedStep: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 原因
                    causeCard

                    // 修复步骤
                    stepsCard

                    // 一键动作
                    if analysis.canAutoFix, let onRetry {
                        autoFixButton(action: onRetry)
                    }

                    // 文档链接
                    docsLink
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 440)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(severityColor.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: analysis.kind.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(severityColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(analysis.title)
                    .font(.system(size: 16, weight: .semibold))
                Text("代码：\(analysis.kind.rawValue)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
            }

            Spacer()

            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    private var severityColor: Color {
        switch analysis.kind.severity {
        case 1: return palette.warning
        case 2: return palette.error
        case 3: return palette.error
        default: return palette.accent
        }
    }

    // MARK: - 原因

    private var causeCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(palette.accent)
                .font(.system(size: 14))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("可能的原因")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                    .textCase(.uppercase)
                Text(analysis.cause)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textPrimary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(palette.surface.opacity(0.5))
        )
    }

    // MARK: - 步骤

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("修复步骤")
                .font(.system(size: 13, weight: .semibold))

            ForEach(Array(analysis.steps.enumerated()), id: \.element.id) { index, step in
                stepRow(index: index, step: step)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.surfaceElevated.opacity(0.4))
        )
    }

    private func stepRow(index: Int, step: ErrorAnalysis.RecoveryStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.2))
                    .frame(width: 24, height: 24)
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.text)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textPrimary)

                if let action = step.action {
                    actionButton(for: action)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionButton(for action: ErrorAnalysis.RecoveryStep.RecoveryAction) -> some View {
        switch action {
        case .openSettings:
            Button("打开设置") {
                // 触发设置页
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .openImport:
            Button("打开导入") {
                NotificationCenter.default.post(name: .openImportRequested, object: nil)
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .retry:
            EmptyView()
        case .openURL(let url):
            Button("打开") {
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .openAIKeySettings:
            Button("配置 API Key") {
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        case .showBackupRestore:
            Button("查看备份") {
                NotificationCenter.default.post(name: .openBackupRequested, object: nil)
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - 自动修复按钮

    private func autoFixButton(action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 16))
                Text("自动重试")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - 文档链接

    private var docsLink: some View {
        HStack {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(palette.textTertiary)
            Text("需要更多帮助？")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
            Button("查看文档") {
                NSWorkspace.shared.open(URL(string: "https://github.com/yourname/WeReadNotes/wiki")!)
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
    }
}

// MARK: - 通知扩展

extension Notification.Name {
    static let openSettingsRequested = Notification.Name("weRead.openSettings")
    static let openImportRequested = Notification.Name("weRead.openImport")
    static let openBackupRequested = Notification.Name("weRead.openBackup")
}

// MARK: - 集成入口

extension ErrorPresenter {
    /// 显示错误恢复向导
    func presentRecovery(for error: Error, context: String = "", retry: (() -> Void)? = nil) {
        let analysis = ErrorAnalyzer.analyze(error, context: context)
        current = nil  // 关闭 banner
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .presentRecoverySheet,
                object: nil,
                userInfo: [
                    "analysis": analysis,
                    "hasRetry": retry != nil
                ]
            )
        }
    }
}

extension Notification.Name {
    static let presentRecoverySheet = Notification.Name("weRead.presentRecovery")
}