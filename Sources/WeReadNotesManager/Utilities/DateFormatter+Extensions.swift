import Foundation

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    static let relative: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    /// yyyy-MM-dd 文件名用。
    static let fileDayStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

extension Date {
    var shortString: String {
        DateFormatter.shortDate.string(from: self)
    }

    var fullString: String {
        DateFormatter.fullDate.string(from: self)
    }

    var relativeString: String {
        DateFormatter.relative.string(from: self)
    }

    var daysSince: Int {
        Self.calendar.dateComponents([.day], from: self, to: Date()).day ?? 0
    }

    /// 共享 Calendar，避免每次访问 Calendar.current 重新构造。
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "zh_CN")
        return cal
    }()
}

/// 预配置的日期解析器，兼容 WeReadSkillImporter 常见的几种时间格式。
enum ChineseDateParser {
    /// 支持的格式，按精确度从高到低排列。
    private static let formats: [String] = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy/MM/dd HH:mm:ss",
        "yyyy/MM/dd HH:mm",
        "yyyy-MM-dd",
        "yyyy/MM/dd"
    ]

    /// 缓存每种格式对应的 DateFormatter。
    private static let formatters: [DateFormatter] = formats.map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = .current
        f.dateFormat = format
        return f
    }

    /// 解析成功返回 `Date`，失败返回 `nil`。
    static func parse(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter.shared.date(from: value) {
            return date
        }
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
