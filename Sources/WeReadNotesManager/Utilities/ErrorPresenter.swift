import Foundation
import SwiftUI

// MARK: - 全局错误展示器
//
// 替换散落在每个 View 里的 `.alert("错误", isPresented: ...)` 重复样板。
// 调用方式：
//   ErrorPresenter.shared.showError(error)
//   ErrorPresenter.shared.showInfo("导入成功")
//   ErrorPresenter.shared.showWarning("网络不稳定")
//
// 设计要点：
// - 单例 + @MainActor，保证 UI 更新线程安全
// - 不阻塞调用方，调用即返回
// - 自动按错误类型归类（网络/数据/AI/未知）

enum ErrorSeverity {
    case info
    case warning
    case error
}

struct PresentedError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let severity: ErrorSeverity
    let systemImage: String

    static func == (lhs: PresentedError, rhs: PresentedError) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
@Observable
final class ErrorPresenter {
    static let shared = ErrorPresenter()

    var current: PresentedError?

    private init() {}

    /// 展示一个错误对象。
    func showError(_ error: Error, title: String? = nil) {
        let nsError = error as NSError
        let displayTitle = title ?? defaultTitle(for: nsError.domain)
        let displayMessage = nsError.localizedDescription
        let severity = inferSeverity(from: nsError)
        let image = defaultImage(for: severity)

        present(
            title: displayTitle,
            message: displayMessage,
            severity: severity,
            systemImage: image
        )
    }

    /// 展示一条提示信息。
    func showInfo(_ message: String, title: String = "提示") {
        present(title: title, message: message, severity: .info, systemImage: "info.circle.fill")
    }

    /// 展示一条警告。
    func showWarning(_ message: String, title: String = "注意") {
        present(title: title, message: message, severity: .warning, systemImage: "exclamationmark.triangle.fill")
    }

    /// 关闭当前错误。
    func dismiss() {
        current = nil
    }

    // MARK: - 私有

    private func present(title: String, message: String, severity: ErrorSeverity, systemImage: String) {
        let err = PresentedError(
            title: title,
            message: message,
            severity: severity,
            systemImage: systemImage
        )
        current = err
    }

    private func defaultTitle(for domain: String) -> String {
        switch domain {
        case NSURLErrorDomain: return "网络错误"
        case "NSCocoaErrorDomain": return "数据错误"
        case "AIErrorDomain": return "AI 服务错误"
        case "WeReadAPIErrorDomain": return "微信读书 API 错误"
        default: return "出错了"
        }
    }

    private func defaultImage(for severity: ErrorSeverity) -> String {
        switch severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private func inferSeverity(from error: NSError) -> ErrorSeverity {
        if error.domain == NSURLErrorDomain {
            return error.code == NSURLErrorCancelled ? .info : .warning
        }
        if error.code == -999 { return .info }
        return .error
    }
}

// MARK: - 全局错误 Banner View

struct GlobalErrorBanner: View {
    @Bindable var presenter: ErrorPresenter
    @Environment(\.themePalette) private var palette

    var body: some View {
        if let error = presenter.current {
            HStack(spacing: 12) {
                Image(systemName: error.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color(for: error.severity))

                VStack(alignment: .leading, spacing: 2) {
                    Text(error.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text(error.message)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Button {
                    presenter.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(palette.textSecondary)
                        .padding(6)
                        .background(Circle().fill(palette.borderSubtle))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color(for: error.severity).opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func color(for severity: ErrorSeverity) -> Color {
        switch severity {
        case .info: return palette.accent
        case .warning: return palette.warning
        case .error: return palette.error
        }
    }
}

// MARK: - View Modifier

extension View {
    /// 在 View 层级底部挂全局错误 banner。
    func globalErrorBanner() -> some View {
        overlay(alignment: .bottom) {
            GlobalErrorBanner(presenter: ErrorPresenter.shared)
        }
    }
}