import SwiftUI
import SwiftData

// MARK: - 时间线视图
//
// 沉浸式时间轴：按月份/年份分组所有笔记
// - 中央竖直时间线
// - 月份分组带标签
// - 每条笔记是一个"时间胶囊"
// - 滚动时自动高亮当前月份

struct ReadingTimelineView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.themePalette) private var palette

    @State private var selectedYear: Int?
    @State private var selectedMonth: Int?
    @State private var scrollAnchorID: String?

    private var timelineData: [TimelineMonth] {
        let calendar = Calendar.current
        let notes = appVM.allNotes.filter { !$0.isDeleted }

        // 按 (year, month) 分组
        var grouped: [String: [ReadingNote]] = [:]
        for note in notes {
            let date = note.createdAt ?? note.importedAt
            let comps = calendar.dateComponents([.year, .month], from: date)
            let key = "\(comps.year ?? 0)-\(comps.month ?? 0)"
            grouped[key, default: []].append(note)
        }

        return grouped.map { (key, notes) -> TimelineMonth in
            let parts = key.split(separator: "-")
            let year = Int(parts[0]) ?? 0
            let month = Int(parts[1]) ?? 0
            let comps = DateComponents(year: year, month: month)
            let date = calendar.date(from: comps) ?? Date()
            return TimelineMonth(
                id: key,
                year: year,
                month: month,
                date: date,
                notes: notes.sorted { ($0.createdAt ?? $0.importedAt) > ($1.createdAt ?? $1.importedAt) }
            )
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：年份导航
            yearSidebar
                .frame(width: 180)
                .background(palette.surface.opacity(0.5))

            // 中央：时间轴
            timeline
        }
        .background(AmbientBackground(showGlows: true, showNoise: true))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 年份侧栏

    private var yearSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YEAR")
                .font(Typography.micro)
                .tracking(1.2)
                .foregroundStyle(palette.textTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(availableYears, id: \.self) { year in
                        Button {
                            withAnimation { selectedYear = year }
                        } label: {
                            HStack {
                                Text(String(year))
                                    .font(.system(size: 16, weight: selectedYear == year ? .bold : .regular, design: .rounded))
                                    .foregroundStyle(selectedYear == year ? palette.accent : palette.textPrimary)
                                Spacer()
                                Text("\(noteCountForYear(year))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(palette.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedYear == year ? palette.accentSoft : .clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    private var availableYears: [Int] {
        let years = Set(timelineData.map(\.year))
        return Array(years).sorted(by: >)
    }

    private func noteCountForYear(_ year: Int) -> Int {
        timelineData.filter { $0.year == year }.reduce(0) { $0 + $1.notes.count }
    }

    // MARK: - 中央时间轴

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .top) {
                    // 中央竖线
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, palette.accent.opacity(0.4), palette.accent.opacity(0.4), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1)
                        .padding(.vertical, 40)
                        .padding(.leading, 60)

                    LazyVStack(alignment: .leading, spacing: 40) {
                        ForEach(displayedMonths) { month in
                            TimelineMonthSection(month: month)
                                .id(month.id)
                                .padding(.horizontal, 20)
                        }

                        // 起点标记
                        TimelineStartMarker()
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 80)
                }
            }
            .onChange(of: selectedYear) { _, new in
                if let new = new, let firstMonth = timelineData.first(where: { $0.year == new }) {
                    withAnimation {
                        proxy.scrollTo(firstMonth.id, anchor: .top)
                    }
                }
            }
            .onAppear {
                if selectedYear == nil {
                    selectedYear = availableYears.first
                }
            }
        }
    }

    private var displayedMonths: [TimelineMonth] {
        if let year = selectedYear {
            return timelineData.filter { $0.year == year }
        }
        return timelineData
    }
}

// MARK: - 时间线月份数据

struct TimelineMonth: Identifiable {
    let id: String
    let year: Int
    let month: Int
    let date: Date
    let notes: [ReadingNote]
}

// MARK: - 月份块

struct TimelineMonthSection: View {
    let month: TimelineMonth

    @Environment(\.themePalette) private var palette
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 月份标签
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 14, height: 14)
                        .shadow(color: palette.accent.opacity(0.4), radius: 6)
                    Circle()
                        .fill(.white)
                        .frame(width: 5, height: 5)
                }

                Text(monthLabel)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .tracking(-0.5)

                Text("\(month.notes.count) 条")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)

                Rectangle()
                    .fill(palette.borderSubtle)
                    .frame(height: 0.5)
            }
            .padding(.leading, 80)

            // 笔记列表
            VStack(alignment: .leading, spacing: 10) {
                ForEach(month.notes) { note in
                    TimelineNoteCard(note: note)
                        .padding(.leading, 80)
                }
            }
        }
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: month.date)
    }
}

// MARK: - 时间线笔记卡片

struct TimelineNoteCard: View {
    let note: ReadingNote

    @Environment(\.themePalette) private var palette
    @Environment(AppViewModel.self) private var appVM
    @State private var hovering = false

    var body: some View {
        Button {
            appVM.selectedNote = note
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // 日期
                VStack(alignment: .center, spacing: 2) {
                    Text(dayString)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.accent)
                    Text(weekdayString)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(palette.textTertiary)
                        .textCase(.uppercase)
                }
                .frame(width: 44)
                .padding(.top, 4)

                // 内容
                VStack(alignment: .leading, spacing: 6) {
                    if let book = note.book {
                        HStack(spacing: 6) {
                            BookCoverView(book: book, size: .small)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(book.title)
                                    .font(Typography.captionStrong)
                                    .foregroundStyle(palette.textPrimary)
                                if let author = book.author {
                                    Text(author)
                                        .font(.system(size: 10))
                                        .foregroundStyle(palette.textTertiary)
                                }
                            }
                        }
                    }

                    Text(note.highlight)
                        .font(Typography.body)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(3)

                    if let userNote = note.userNote, !userNote.isEmpty {
                        Text(userNote)
                            .font(Typography.caption)
                            .foregroundStyle(palette.textSecondary)
                            .italic()
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        if note.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(palette.warning)
                        }
                        if let chapter = note.chapter {
                            Text(chapter)
                                .font(.system(size: 10))
                                .foregroundStyle(palette.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(palette.surface.opacity(hovering ? 0.85 : 0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(hovering ? palette.accent.opacity(0.3) : palette.borderSubtle, lineWidth: 0.5)
            )
            .scaleEffect(hovering ? 1.01 : 1)
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: hovering)
        }
        .buttonStyle(.plain)
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: note.createdAt ?? note.importedAt)
    }

    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter.string(from: note.createdAt ?? note.importedAt)
    }
}

// MARK: - 起点标记

struct TimelineStartMarker: View {
    @Environment(\.themePalette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(palette.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: 14, height: 14)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(palette.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("阅读旅程从这里开始")
                    .font(Typography.bodyStrong)
                    .foregroundStyle(palette.textPrimary)
                Text("继续记录你的思考与灵感")
                    .font(Typography.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()
        }
        .padding(.leading, 80)
        .padding(.vertical, 12)
    }
}