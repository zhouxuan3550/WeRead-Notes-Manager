import SwiftUI
import SwiftData
import Charts

// MARK: - 统计仪表盘（升级版）
//
// 用 Swift Charts 替换硬编码色块：
// - 4 维统计环（StatRingCard）
// - 90 天笔记趋势折线
// - Top 5 书籍柱状图
// - 全年阅读热力图

struct StatsDashboardView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.themePalette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                // 4 维统计环
                statRingRow

                // 90 天趋势
                trendSection

                Divider().padding(.vertical, 4)

                // 热力图 + Top 书籍 双栏
                HStack(alignment: .top, spacing: 16) {
                    HeatmapCalendarView(
                        counts: heatmapData,
                        totalLabel: "过去一年 · \(heatmapData.values.reduce(0, +)) 条笔记",
                        streakLabel: "日均 \(String(format: "%.1f", dailyAverage)) 条"
                    )
                    .frame(maxWidth: .infinity)

                    topBooksCard
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("统计仪表盘")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(palette.textPrimary)
            Text("全面了解你的阅读笔记、复习进度和知识积累。")
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: - 4 维统计环

    private var statRingRow: some View {
        let reviewedCount = appVM.allNotes.filter(\.isReviewed).count
        return HStack(spacing: 14) {
            StatRingCard(
                title: "书籍",
                value: appVM.books.count,
                total: max(1, appVM.books.count),
                color: palette.accent,
                systemImage: "books.vertical.fill"
            )
            StatRingCard(
                title: "笔记",
                value: appVM.allNotes.count,
                total: max(1, appVM.allNotes.count),
                color: palette.success,
                systemImage: "note.text"
            )
            StatRingCard(
                title: "已复习",
                value: reviewedCount,
                total: max(1, appVM.allNotes.count),
                color: palette.warning,
                systemImage: "checkmark.circle.fill"
            )
            StatRingCard(
                title: "待复习",
                value: appVM.dueNotes.count,
                total: max(1, appVM.allNotes.count),
                color: palette.error,
                systemImage: "clock.fill"
            )
        }
    }

    // MARK: - 趋势折线

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("近 90 天笔记趋势")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("共 \(trendData.reduce(0) { $0 + $1.count }) 条")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
            }

            NoteTrendChart(data: trendData)
                .frame(height: 180)
        }
        .padding(16)
        .premiumGlassPanel(cornerRadius: DesignSystem.CornerRadius.lg)
    }

    // MARK: - Top 书籍

    private var topBooksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top 书籍")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            let topBooks = appVM.books
                .filter { !$0.notes.isEmpty }
                .sorted { $0.notes.count > $1.notes.count }
                .prefix(8)

            if topBooks.isEmpty {
                Text("同步笔记后将显示 Top 书籍")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textTertiary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(topBooks.enumerated()), id: \.offset) { idx, book in
                        HStack(spacing: 10) {
                            Text("\(idx + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.accent)
                                .frame(width: 18)
                            BookCoverView(book: book, size: .small)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(book.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(palette.textPrimary)
                                    .lineLimit(1)
                                Text("\(book.notes.count) 条 · \(book.notes.filter(\.isFavorite).count) 收藏")
                                    .font(.system(size: 10))
                                    .foregroundStyle(palette.textSecondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumGlassPanel(cornerRadius: DesignSystem.CornerRadius.lg)
    }

    // MARK: - 数据计算

    private var trendData: [NoteCountByDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var byDay: [Date: Int] = [:]

        for note in appVM.allNotes where !note.isDeleted {
            let date = note.createdAt ?? note.importedAt
            let day = calendar.startOfDay(for: date)
            byDay[day, default: 0] += 1
        }

        var result: [NoteCountByDay] = []
        for offset in (0..<90).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            result.append(NoteCountByDay(date: day, count: byDay[day] ?? 0))
        }
        return result
    }

    private var heatmapData: [DateComponents: Int] {
        let calendar = Calendar.current
        var result: [DateComponents: Int] = [:]
        for note in appVM.allNotes where !note.isDeleted {
            let date = note.createdAt ?? note.importedAt
            let key = calendar.dateComponents([.year, .month, .day], from: date)
            result[key, default: 0] += 1
        }
        return result
    }

    private var dailyAverage: Double {
        let total = heatmapData.values.reduce(0, +)
        return Double(total) / 365.0
    }
}