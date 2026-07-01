import SwiftUI
import Charts

// MARK: - 数据图表集合
//
// 用 Swift Charts 替换 StatsDashboardView 的硬编码色块。
// 主题感知、交互丰富、视觉高端。

// MARK: - 数据结构

struct NoteCountByDay: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct TagCount: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let color: Color
}

struct ChapterCount: Identifiable {
    let id = UUID()
    let chapter: String
    let count: Int
}

// MARK: - 1. 笔记趋势线图

struct NoteTrendChart: View {
    let data: [NoteCountByDay]

    @Environment(\.themePalette) private var palette

    var body: some View {
        Chart(data) { item in
            // 渐变填充面积
            AreaMark(
                x: .value("日期", item.date),
                y: .value("笔记", item.count)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [palette.accent.opacity(0.45), palette.accent.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // 折线
            LineMark(
                x: .value("日期", item.date),
                y: .value("笔记", item.count)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(palette.accent)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

            // 数据点
            PointMark(
                x: .value("日期", item.date),
                y: .value("笔记", item.count)
            )
            .foregroundStyle(palette.accent)
            .symbolSize(40)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine().foregroundStyle(palette.borderSubtle)
                AxisTick().foregroundStyle(palette.borderSubtle)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(palette.borderSubtle)
                AxisValueLabel().foregroundStyle(palette.textSecondary)
            }
        }
        .chartYScale(domain: 0...max(1, (data.map(\.count).max() ?? 1) + 2))
        .chartPlotStyle { plot in
            plot
                .background(palette.surface.opacity(0.4))
                .cornerRadius(8)
        }
    }
}

// MARK: - 2. 标签分布柱状图

struct TagDistributionChart: View {
    let data: [TagCount]

    @Environment(\.themePalette) private var palette

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("数量", item.count),
                y: .value("标签", item.name)
            )
            .foregroundStyle(item.color.gradient)
            .cornerRadius(4)
            .annotation(position: .trailing) {
                Text("\(item.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(palette.borderSubtle)
                AxisValueLabel().foregroundStyle(palette.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel().foregroundStyle(palette.textSecondary)
            }
        }
        .chartPlotStyle { plot in
            plot.background(palette.surface.opacity(0.3)).cornerRadius(8)
        }
    }
}

// MARK: - 3. 章节分布极坐标图

struct ChapterPolarChart: View {
    let data: [ChapterCount]

    @Environment(\.themePalette) private var palette

    var body: some View {
        Chart(data) { item in
            SectorMark(
                angle: .value("笔记", item.count),
                innerRadius: .ratio(0.55),
                angularInset: 2
            )
            .cornerRadius(4)
            .foregroundStyle(by: .value("章节", item.chapter))
            .opacity(0.9)
        }
        .chartLegend(position: .trailing, alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(data) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(palette.accent.opacity(0.7))
                            .frame(width: 8, height: 8)
                        Text(item.chapter)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.textPrimary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }
}

// MARK: - 4. 复习分布点图

struct ReviewDistributionChart: View {
    let data: [NoteCountByDay]

    @Environment(\.themePalette) private var palette

    var body: some View {
        Chart(data) { item in
            PointMark(
                x: .value("日期", item.date),
                y: .value("笔记", item.count)
            )
            .foregroundStyle(palette.accent.opacity(0.85))
            .symbolSize(item.count > 0 ? 80 : 20)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine().foregroundStyle(palette.borderSubtle)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.background(palette.surface.opacity(0.3)).cornerRadius(8)
        }
    }
}

// MARK: - 数据汇总卡片

struct StatRingCard: View {
    let title: String
    let value: Int
    let total: Int
    let color: Color
    let systemImage: String

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(color.opacity(0.15))
                    )
                Spacer()
                Text("\(Int(Double(value) / Double(max(1, total)) * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }

            ZStack {
                Circle()
                    .stroke(palette.borderSubtle, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(DesignSystem.Animation.slow, value: progress)
                VStack(spacing: 0) {
                    AnimatedNumber(
                        targetValue: value,
                        duration: 1.2,
                        font: .system(size: 22, weight: .bold).monospacedDigit(),
                        color: palette.textPrimary
                    )
                    Text("/ \(total)")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .frame(height: 76)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumGlassPanel(cornerRadius: DesignSystem.CornerRadius.lg)
    }

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(value) / Double(total))
    }
}