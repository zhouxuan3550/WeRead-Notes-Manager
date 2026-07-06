import WidgetKit
import SwiftUI

// MARK: - WidgetKit 桌面小组件
//
// macOS 14+ 桌面/通知中心小组件：
// - small：今日 due 数 + 简短标签
// - medium：今日 due + Top 3 笔记预览
// - large：今日 due + 5 笔记预览 + 复习按钮
//
// 数据通过 App Group 共享，主 App 写入 → Widget 读取。

// MARK: - 时间线条目

struct DueNotesEntry: TimelineEntry {
    let date: Date
    let dueCount: Int
    let totalCount: Int
    let topNotes: [WidgetNote]
    let theme: WidgetTheme

    struct WidgetNote: Hashable {
        let id: String
        let bookTitle: String
        let highlight: String
        let chapter: String?
    }
}

enum WidgetTheme: String {
    case midnight, paper, ink, forest

    var backgroundHex: String {
        switch self {
        case .midnight: return "#0F1115"
        case .paper: return "#F5EEDC"
        case .ink: return "#1A1A1A"
        case .forest: return "#0C1F18"
        }
    }

    var accentHex: String {
        switch self {
        case .midnight: return "#5B8DEF"
        case .paper: return "#A23B2E"
        case .ink: return "#D9D9D9"
        case .forest: return "#7AD89E"
        }
    }

    var textHex: String {
        switch self {
        case .midnight: return "#EBEDF2"
        case .paper: return "#2E2114"
        case .ink: return "#EBEDF2"
        case .forest: return "#EAF5EE"
        }
    }
}

// MARK: - Provider

struct DueNotesProvider: TimelineProvider {
    func placeholder(in context: Context) -> DueNotesEntry {
        DueNotesEntry(
            date: .now,
            dueCount: 12,
            totalCount: 234,
            topNotes: [
                .init(id: "1", bookTitle: "思考，快与慢", highlight: "人类的大脑有两种思考模式……", chapter: nil),
                .init(id: "2", bookTitle: "原则", highlight: "痛苦 + 反思 = 进步", chapter: nil),
                .init(id: "3", bookTitle: "人类简史", highlight: "我们以为自己很了解自己……", chapter: nil)
            ],
            theme: .midnight
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DueNotesEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DueNotesEntry>) -> Void) {
        // Widget 不能直接访问主 App 的 SwiftData；
        // 这里从 App Group UserDefaults 读出主 App 推送的数据
        let store = WidgetDataStore.shared
        let entry = DueNotesEntry(
            date: .now,
            dueCount: store.dueCount,
            totalCount: store.totalCount,
            topNotes: store.topNotes,
            theme: WidgetTheme(rawValue: store.theme) ?? .midnight
        )

        // 每小时刷新一次
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Data Store

/// 主 App 和 Widget 共享的轻量数据。
/// 主 App 在 SwiftData 变更时调用 `update(...)` 推送最新快照。
final class WidgetDataStore {
    static let shared = WidgetDataStore()

    private let defaults: UserDefaults

    /// App Group ID（需要在 Xcode Capabilities 里配置 com.weread.notesmanager）
    private let appGroupID = "group.com.weread.notesmanager"

    private init() {
        if let groupDefaults = UserDefaults(suiteName: appGroupID) {
            self.defaults = groupDefaults
        } else {
            // 降级：使用标准 UserDefaults（开发期）
            self.defaults = .standard
        }
    }

    var dueCount: Int {
        get { defaults.integer(forKey: "widget.dueCount") }
        set { defaults.set(newValue, forKey: "widget.dueCount") }
    }

    var totalCount: Int {
        get { defaults.integer(forKey: "widget.totalCount") }
        set { defaults.set(newValue, forKey: "widget.totalCount") }
    }

    var theme: String {
        get { defaults.string(forKey: "widget.theme") ?? "midnight" }
        set { defaults.set(newValue, forKey: "widget.theme") }
    }

    var topNotes: [DueNotesEntry.WidgetNote] {
        get {
            guard let data = defaults.data(forKey: "widget.topNotes"),
                  let list = try? JSONDecoder().decode([WidgetNoteData].self, from: data) else {
                return []
            }
            return list.map {
                DueNotesEntry.WidgetNote(id: $0.id, bookTitle: $0.bookTitle, highlight: $0.highlight, chapter: $0.chapter)
            }
        }
        set {
            let data = newValue.map {
                WidgetNoteData(id: $0.id, bookTitle: $0.bookTitle, highlight: $0.highlight, chapter: $0.chapter)
            }
            if let encoded = try? JSONEncoder().encode(data) {
                defaults.set(encoded, forKey: "widget.topNotes")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// 主 App 调用：推送最新快照
    func update(dueCount: Int, totalCount: Int, theme: String, topNotes: [DueNotesEntry.WidgetNote]) {
        self.dueCount = dueCount
        self.totalCount = totalCount
        self.theme = theme
        self.topNotes = topNotes
    }

    private struct WidgetNoteData: Codable {
        let id: String
        let bookTitle: String
        let highlight: String
        let chapter: String?
    }
}

// MARK: - Widget View

struct DueNotesWidgetView: View {
    let entry: DueNotesEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        case .systemLarge: largeView
        default: smallView
        }
    }

    // 颜色工具
    private var bg: Color { Color(hex: entry.theme.backgroundHex) ?? .black }
    private var accent: Color { Color(hex: entry.theme.accentHex) ?? .blue }
    private var textPrimary: Color { Color(hex: entry.theme.textHex) ?? .white }

    // small
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundStyle(accent)
                Text("待复习")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textPrimary.opacity(0.7))
                Spacer()
            }
            Text("\(entry.dueCount)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
            Text("/ \(entry.totalCount) 条总笔记")
                .font(.system(size: 10))
                .foregroundStyle(textPrimary.opacity(0.5))
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "books.vertical.fill")
                Text("树懒书摘")
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(textPrimary.opacity(0.5))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
    }

    // medium
    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.stack.fill")
                            .foregroundStyle(accent)
                        Text("今日待复习")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(textPrimary)
                    }
                    Text("\(entry.dueCount) 条 · 总 \(entry.totalCount) 条")
                        .font(.system(size: 10))
                        .foregroundStyle(textPrimary.opacity(0.5))
                }
                Spacer()
                Text("\(entry.dueCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
            }

            Divider().overlay(textPrimary.opacity(0.15))

            ForEach(entry.topNotes.prefix(2), id: \.self) { note in
                HStack(alignment: .top, spacing: 6) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(note.bookTitle)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(textPrimary.opacity(0.7))
                            .lineLimit(1)
                        Text(note.highlight)
                            .font(.system(size: 11))
                            .foregroundStyle(textPrimary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
    }

    // large
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.stack.fill")
                            .foregroundStyle(accent)
                        Text("今日待复习")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(textPrimary)
                    }
                    Text("\(entry.dueCount) 条 · 总 \(entry.totalCount) 条")
                        .font(.system(size: 11))
                        .foregroundStyle(textPrimary.opacity(0.5))
                }
                Spacer()
                Text("\(entry.dueCount)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
            }

            Divider().overlay(textPrimary.opacity(0.15))

            ForEach(entry.topNotes.prefix(4), id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 2.5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(note.bookTitle)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(textPrimary.opacity(0.7))
                            .lineLimit(1)
                        Text(note.highlight)
                            .font(.system(size: 11))
                            .foregroundStyle(textPrimary)
                            .lineLimit(2)
                    }
                }
            }

            Spacer()
            HStack {
                Text("树懒书摘")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(textPrimary.opacity(0.5))
                Spacer()
                Link(destination: URL(string: "weread://review")!) {
                    HStack(spacing: 4) {
                        Text("开始复习")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(accent)
                    )
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
    }
}

// MARK: - Widget 定义

struct DueNotesWidget: Widget {
    let kind: String = "WeReadDueNotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DueNotesProvider()) { entry in
            DueNotesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("树懒书摘 · 待复习")
        .description("一眼看到今天的复习任务")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

struct WeReadWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DueNotesWidget()
    }
}