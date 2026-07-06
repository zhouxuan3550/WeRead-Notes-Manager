import AppIntents
import SwiftData
import Foundation
import AppKit

// MARK: - Shortcuts / Siri 集成
//
// 用户可以通过 Siri 或 Shortcuts App 调用：
// - "Hey Siri, 今天复习几条" → 返回待复习数
// - "Hey Siri, 打开树懒书摘"
// - Shortcuts 里把笔记导出为 Markdown / Obsidian
//
// 通过 AppIntents 框架实现（macOS 13+）。

// MARK: - 1. 打开主窗口

struct OpenMainWindowIntent: AppIntent {
    static var title: LocalizedStringResource = "打开树懒书摘"
    static var description = IntentDescription("打开树懒书摘主窗口")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return .result()
    }
}

// MARK: - 2. 快速记录

struct QuickCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "快速记录笔记"
    static var description = IntentDescription("弹出快速记录窗口")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "内容")
    var content: String?

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .quickCaptureRequested,
                object: nil,
                userInfo: content.map { ["content": $0] }
            )
            NSApp.activate(ignoringOtherApps: true)
        }
        return .result()
    }
}

// MARK: - 3. 查询待复习数

struct DueNotesCountIntent: AppIntent {
    static var title: LocalizedStringResource = "查看待复习笔记"
    static var description = IntentDescription("返回当前待复习笔记的数量")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = await countDueNotes()
        let message = count > 0 ? "今天还有 \(count) 条笔记待复习" : "今天没有待复习的笔记，做得很棒！"
        return .result(dialog: IntentDialog(stringLiteral: message))
    }

    @MainActor
    private func countDueNotes() async -> Int {
        guard let context = try? ModelContainer(for: Book.self, ReadingNote.self, ImportRecord.self, Tag.self, BookSummary.self).mainContext else {
            return 0
        }
        let descriptor = FetchDescriptor<ReadingNote>(
            predicate: #Predicate { !$0.isDeleted }
        )
        let now = Date()
        let notes = (try? context.fetch(descriptor)) ?? []
        return notes.filter { note in
            if let next = note.nextReviewAt { return next <= now }
            return true
        }.count
    }
}

// MARK: - 4. 随机一条笔记

struct RandomNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "随机笔记"
    static var description = IntentDescription("返回一条随机笔记的内容")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let note = await pickRandomNote() else {
            return .result(dialog: IntentDialog("暂无可用笔记"))
        }
        let text = "《\(note.book?.title ?? "未知")》：\(String(note.highlight.prefix(120)))"
        return .result(dialog: IntentDialog(stringLiteral: text))
    }

    @MainActor
    private func pickRandomNote() async -> ReadingNote? {
        guard let context = try? ModelContainer(for: Book.self, ReadingNote.self, ImportRecord.self, Tag.self, BookSummary.self).mainContext else {
            return nil
        }
        var descriptor = FetchDescriptor<ReadingNote>(
            predicate: #Predicate { !$0.isDeleted }
        )
        descriptor.fetchLimit = 50
        let notes = (try? context.fetch(descriptor)) ?? []
        return notes.randomElement()
    }
}

// MARK: - 5. AppShortcuts 提供器

struct WeReadShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenMainWindowIntent(),
            phrases: [
                "打开 \(.applicationName)",
                "启动 \(.applicationName)"
            ],
            shortTitle: "打开树懒书摘",
            systemImageName: "books.vertical"
        )

        AppShortcut(
            intent: QuickCaptureIntent(),
            phrases: [
                "用 \(.applicationName) 记笔记",
                "在 \(.applicationName) 里快速记录"
            ],
            shortTitle: "快速记录",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: DueNotesCountIntent(),
            phrases: [
                "\(.applicationName) 今天要复习几条",
                "查看 \(.applicationName) 待复习"
            ],
            shortTitle: "待复习数",
            systemImageName: "rectangle.stack"
        )

        AppShortcut(
            intent: RandomNoteIntent(),
            phrases: [
                "随机一条 \(.applicationName) 笔记",
                "\(.applicationName) 给我看看"
            ],
            shortTitle: "随机笔记",
            systemImageName: "shuffle"
        )
    }
}

// MARK: - 通知扩展

extension Notification.Name {
    static let quickCaptureRequested = Notification.Name("weRead.quickCaptureRequested")
    static let ocrCaptureRequested = Notification.Name("weRead.ocrCaptureRequested")
}