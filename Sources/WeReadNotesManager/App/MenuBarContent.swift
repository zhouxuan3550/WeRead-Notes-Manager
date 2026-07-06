import SwiftUI
import SwiftData

// MARK: - 菜单栏下拉内容
//
// 显示今日数据 + 快捷动作 + 退出

struct MenuBarContent: View {
    let showQuickCapture: () -> Void
    let showMainWindow: () -> Void

    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @Environment(\.themePalette) private var palette

    private var dueCount: Int {
        let now = Date()
        var count = 0
        for book in books {
            for note in book.notes where !note.isDeleted {
                if let next = note.nextReviewAt, next <= now {
                    count += 1
                } else if note.nextReviewAt == nil {
                    count += 1
                }
            }
        }
        return count
    }

    private var todayImported: Int {
        let cal = Calendar.current
        return books.flatMap(\.notes)
            .filter { cal.isDateInToday($0.importedAt) }
            .count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部数据卡
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Text("树懒书摘")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                }

                HStack(spacing: 14) {
                    dataChip(value: "\(dueCount)", label: "待复习", color: palette.warning)
                    dataChip(value: "\(books.count)", label: "书籍", color: palette.accent)
                    dataChip(value: "\(todayImported)", label: "今日", color: palette.success)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(palette.surface.opacity(0.5))

            Divider()

            // 快捷动作
            Button {
                showQuickCapture()
            } label: {
                Label("快速记录...", systemImage: "square.and.pencil")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button {
                showMainWindow()
                // 模拟点击 review 侧栏
            } label: {
                Label("去复习 (\(dueCount) 条)", systemImage: "rectangle.stack")
            }

            Button {
                showMainWindow()
            } label: {
                Label("显示主窗口", systemImage: "macwindow")
            }

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
        }
    }

    private func dataChip(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(palette.textTertiary)
        }
    }
}

// MARK: - 菜单栏图标（带 due 数字角标）

struct MenuBarLabel: View {
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @Environment(\.themePalette) private var palette

    private var dueCount: Int {
        let now = Date()
        return books.flatMap(\.notes)
            .filter { !$0.isDeleted }
            .filter { note in
                if let next = note.nextReviewAt { return next <= now }
                return true
            }
            .count
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "books.vertical.fill")
                .symbolRenderingMode(.hierarchical)
            if dueCount > 0 {
                Text("\(min(dueCount, 99))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(palette.warning)
                    )
                    .offset(x: 6, y: -4)
            }
        }
    }
}