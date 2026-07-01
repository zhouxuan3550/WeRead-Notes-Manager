import SwiftUI

// MARK: - 阅读热力图（GitHub Contributions 风格）
//
// 365 格日历，每个格子代表一天，颜色深浅代表当天笔记/复习数。
// 鼠标悬停显示日期 + 数量。

struct HeatmapCalendarView: View {
    /// key: 日期（y/m/d），value: 数量
    let counts: [DateComponents: Int]
    /// 自定义总览语
    let totalLabel: String
    let streakLabel: String

    @Environment(\.themePalette) private var palette
    @State private var hoverInfo: (date: Date, count: Int)?

    private let weeks = 53
    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3
    private let weekdayLabels = ["", "周一", "", "周三", "", "周五", ""]

    init(
        counts: [DateComponents: Int] = [:],
        totalLabel: String? = nil,
        streakLabel: String? = nil
    ) {
        self.counts = counts
        self.totalLabel = totalLabel ?? "\(counts.values.reduce(0, +)) 条笔记"
        self.streakLabel = streakLabel ?? "过去一年"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            grid
            legend
        }
        .padding(16)
        .premiumGlassPanel(cornerRadius: DesignSystem.CornerRadius.lg)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("阅读日历")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(totalLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
            Text(streakLabel)
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)
        }
    }

    // MARK: - 网格

    private var grid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: cellSpacing) {
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7) { row in
                            Text(weekdayLabels[row])
                                .font(.system(size: 9))
                                .foregroundStyle(palette.textTertiary)
                                .frame(width: 22, height: cellSize, alignment: .leading)
                        }
                    }

                    HStack(alignment: .top, spacing: cellSpacing) {
                        ForEach(0..<weeks, id: \.self) { week in
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<7, id: \.self) { day in
                                    cellView(week: week, day: day)
                                }
                            }
                        }
                    }
                }
                monthLabels
            }
        }
    }

    private func cellView(week: Int, day: Int) -> some View {
        let date = dateFor(week: week, day: day)
        let key = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let count = counts[key] ?? 0
        let color = colorForCount(count)

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: cellSize, height: cellSize)
            .onHover { hovering in
                if hovering {
                    hoverInfo = (date, count)
                } else if hoverInfo?.date == date {
                    hoverInfo = nil
                }
            }
            .help("\(date.shortString) · \(count) 条")
    }

    // MARK: - 月份标签

    private var monthLabels: some View {
        HStack(spacing: cellSpacing) {
            Spacer().frame(width: 22)
            HStack(alignment: .center, spacing: cellSpacing) {
                ForEach(0..<weeks, id: \.self) { week in
                    let d = dateFor(week: week, day: 0)
                    let isFirstWeekOfMonth = Calendar.current.component(.day, from: d) <= 7
                    Text(isFirstWeekOfMonth ? monthShort(d) : "")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.textTertiary)
                        .frame(width: cellSize, alignment: .leading)
                }
            }
        }
    }

    // MARK: - 图例

    private var legend: some View {
        HStack(spacing: 8) {
            Text("少")
                .font(.system(size: 10))
                .foregroundStyle(palette.textTertiary)
            ForEach(0..<5) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(colorForLevel(level))
                    .frame(width: 11, height: 11)
            }
            Text("多")
                .font(.system(size: 10))
                .foregroundStyle(palette.textTertiary)

            Spacer()

            if let info = hoverInfo {
                Text("\(info.date.shortString) · \(info.count) 条")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(palette.surfaceElevated)
                    )
                    .transition(.opacity)
            }
        }
    }

    // MARK: - 工具

    private func dateFor(week: Int, day: Int) -> Date {
        let calendar = Calendar.current
        // 以一年前的今天为终点，反推 weeks 周
        let endDate = calendar.startOfDay(for: Date())
        let endWeekday = calendar.component(.weekday, from: endDate) - 1 // 0..6
        let daysFromEnd = (weeks - 1 - week) * 7 + (6 - endWeekday) + day
        return calendar.date(byAdding: .day, value: -daysFromEnd, to: endDate) ?? endDate
    }

    private func monthShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter.string(from: date)
    }

    private func colorForCount(_ count: Int) -> Color {
        let level = levelForCount(count)
        return colorForLevel(level)
    }

    private func levelForCount(_ count: Int) -> Int {
        switch count {
        case 0: return 0
        case 1: return 1
        case 2...3: return 2
        case 4...7: return 3
        default: return 4
        }
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: return palette.surface.opacity(0.7)
        case 1: return palette.accent.opacity(0.25)
        case 2: return palette.accent.opacity(0.50)
        case 3: return palette.accent.opacity(0.75)
        default: return palette.accent
        }
    }
}

// MARK: - 预设构造器

extension HeatmapCalendarView {
    /// 从笔记列表构造热力图（按 createdAt 分组）。
    /// 这里不直接引用 ReadingNote，避免对 Models 模块的循环依赖；
    /// 调用方负责把笔记数据扁平化成 [(date, count)] 后再传入。
    static func aggregate(_ items: [(date: Date, count: Int)]) -> [DateComponents: Int] {
        var result: [DateComponents: Int] = [:]
        let calendar = Calendar.current
        for item in items {
            let key = calendar.dateComponents([.year, .month, .day], from: item.date)
            result[key, default: 0] += item.count
        }
        return result
    }
}