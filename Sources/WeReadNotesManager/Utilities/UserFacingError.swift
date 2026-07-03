import Foundation

enum UserFacingError {
    static func message(for error: Error, context: String) -> String {
        let raw = error.localizedDescription
        let lowered = raw.lowercased()

        if lowered.contains("network") || lowered.contains("timed out") || lowered.contains("offline") {
            return "\(context)失败：网络连接不稳定。请确认能访问微信读书或 GitHub 后再试。"
        }

        if lowered.contains("401") || lowered.contains("unauthorized") || lowered.contains("forbidden") {
            return "\(context)失败：授权信息可能已失效。请重新粘贴并保存 API Key。"
        }

        if lowered.contains("unsupported") || raw.contains("不支持") {
            return "\(context)失败：文件格式暂不支持。建议使用微信读书 TXT、Markdown 或普通 TXT。"
        }

        if lowered.contains("not found") || raw.contains("找不到") {
            return "\(context)失败：没有找到需要的文件或数据。"
        }

        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(context)失败：发生未知错误，请稍后再试。"
        }

        return "\(context)失败：\(raw)"
    }
}
