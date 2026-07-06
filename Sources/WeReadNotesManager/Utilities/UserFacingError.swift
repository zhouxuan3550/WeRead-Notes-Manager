import Foundation

enum UserFacingError {
    static func message(for error: Error, context: String) -> String {
        let raw = error.localizedDescription
        let lowered = raw.lowercased()

        if raw.contains("Skill 有新版本") || raw.contains("upgrade_url") || raw.contains("需要更新") {
            return "\(context)失败：微信读书同步接口需要更新。请重新保存微信读书 API Key；如果仍失败，请到 GitHub Releases 下载最新版后再试。"
        }

        if raw.contains("请先填写微信读书 API Key") || lowered.contains("missing api key") {
            return "\(context)失败：还没有配置微信读书 API Key。请打开导入与同步，粘贴并保存 wrk- 开头的 Key。"
        }

        if lowered.contains("network") || lowered.contains("timed out") || lowered.contains("offline") {
            return "\(context)失败：网络连接不稳定。请确认能访问微信读书，稍后点击“重试”。"
        }

        if lowered.contains("401") || lowered.contains("unauthorized") || lowered.contains("forbidden") || lowered.contains("403") {
            return "\(context)失败：授权信息可能已失效。请重新粘贴并保存 API Key。"
        }

        if lowered.contains("429") || lowered.contains("too many requests") || raw.contains("频率") || raw.contains("限流") {
            return "\(context)失败：请求过于频繁。请等几分钟后再同步。"
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
