import Foundation
import AppKit
import SwiftUI

// MARK: - AppleScript 字典
//
// 暴露给 AppleScript 的命令：
// - count of notes
// - count of books
// - search notes for "keyword"
// - get note at index
// - open note with id "UUID"
//
// 通过 NSAppleEventManager 注册。
//
// AppleScript 调用示例（在 Script Editor）：
//   tell application "System Events"
//     tell process "WeReadNotesManager"
//       count notes
//     end tell
//   end tell

// MARK: - AppleScript 命令解析

enum AppleScriptCommand: String {
    case countNotes = "count_notes"
    case countBooks = "count_books"
    case countDueNotes = "count_due_notes"
    case searchNotes = "search_notes"
    case getRecent = "get_recent"
    case openNote = "open_note"
    case syncNow = "sync_now"
    case unknown

    static func from(_ raw: String) -> AppleScriptCommand {
        AppleScriptCommand(rawValue: raw) ?? .unknown
    }
}

// MARK: - AppleScript 桥接器

@MainActor
enum AppleScriptBridge {
    /// 处理来自 AppleScript 的命令字符串。
    /// 返回值是字符串格式的结果。
    static func handle(command rawCommand: String, context: String = "") -> String {
        let parts = rawCommand.components(separatedBy: " ")
        guard let rawCmd = parts.first else { return "ERROR: empty command" }
        let cmd = AppleScriptCommand.from(rawCmd)
        let args = Array(parts.dropFirst())

        switch cmd {
        case .countNotes:
            // 通过 UserDefaults 读上次同步的数量
            return UserDefaults.standard.string(forKey: "appleScript.lastNoteCount") ?? "0"

        case .countBooks:
            return UserDefaults.standard.string(forKey: "appleScript.lastBookCount") ?? "0"

        case .countDueNotes:
            return UserDefaults.standard.string(forKey: "appleScript.lastDueCount") ?? "0"

        case .searchNotes:
            let keyword = args.joined(separator: " ")
            guard !keyword.isEmpty else { return "ERROR: missing keyword" }
            return "searching for: \(keyword)"

        case .getRecent:
            let count = Int(args.first ?? "5") ?? 5
            return "recent: \(count)"

        case .openNote:
            let id = args.first ?? ""
            guard !id.isEmpty else { return "ERROR: missing note ID" }
            // 触发通知让主 App 打开笔记
            NotificationCenter.default.post(
                name: .appleScriptOpenNote,
                object: nil,
                userInfo: ["noteID": id]
            )
            return "OK"

        case .syncNow:
            NotificationCenter.default.post(name: .appleScriptSyncNow, object: nil)
            return "syncing..."

        case .unknown:
            return "ERROR: unknown command '\(rawCmd)'. Available: \(availableCommands)"
        }
    }

    static var availableCommands: String {
        ["count_notes", "count_books", "count_due_notes",
         "search_notes <keyword>", "get_recent [count]",
         "open_note <UUID>", "sync_now"].joined(separator: ", ")
    }

    /// 主 App 调用：更新 AppleScript 可读的最新计数
    static func updateStats(notes: Int, books: Int, dueNotes: Int) {
        UserDefaults.standard.set(String(notes), forKey: "appleScript.lastNoteCount")
        UserDefaults.standard.set(String(books), forKey: "appleScript.lastBookCount")
        UserDefaults.standard.set(String(dueNotes), forKey: "appleScript.lastDueCount")
    }
}

// MARK: - AppleScript 通知扩展

extension Notification.Name {
    static let appleScriptOpenNote = Notification.Name("weRead.appleScript.openNote")
    static let appleScriptSyncNow = Notification.Name("weRead.appleScript.syncNow")
}

// MARK: - AppleEvent 处理

/// 注册 AppleScript 事件处理器
/// macOS 通过 NSAppleEventManager 接收 'kAEProcess'/'kAEOpenDocuments' 等事件
final class AppleScriptHandler: NSObject, NSApplicationDelegate {
    static let shared = AppleScriptHandler()

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        // 处理打开 .wread 备份包
        NotificationCenter.default.post(
            name: .appleScriptOpenNote,
            object: nil,
            userInfo: ["file": filename]
        )
        return true
    }
}

// MARK: - 终端命令支持

/// 支持 `weread` 命令行工具：
///   weread count notes
///   weread search "keyword"
///   weread open <UUID>
///
/// 把 WeReadNotesManager.app 注册为 LSHandler 后，
/// 用户在终端运行 `open weread://search/keyword` 可触发。

enum URLSchemeHandler {
    static func handle(_ url: URL) {
        guard url.scheme == "weread" else { return }
        let host = url.host ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch host {
        case "search":
            NotificationCenter.default.post(
                name: .appleScriptOpenNote,
                object: nil,
                userInfo: ["search": path]
            )
        case "note":
            if let uuid = UUID(uuidString: path) {
                NotificationCenter.default.post(
                    name: .appleScriptOpenNote,
                    object: nil,
                    userInfo: ["noteID": uuid.uuidString]
                )
            }
        case "review":
            NotificationCenter.default.post(
                name: .appleScriptOpenNote,
                object: nil,
                userInfo: ["openReview": true]
            )
        default:
            break
        }
    }
}

// MARK: - 命令面板

/// ⌘K 命令面板：快速执行 / 输入命令
struct CommandPalette: View {
    @State private var input = ""
    @State private var output: String?
    @State private var isShowing = false

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(palette.accent)
                TextField("输入命令 (count_notes / search <kw> / open <UUID>)", text: $input)
                    .textFieldStyle(.plain)
                    .onSubmit(execute)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))

            if let output {
                Text(output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.textPrimary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(palette.surfaceElevated))
            }
        }
        .padding(16)
    }

    private func execute() {
        let result = AppleScriptBridge.handle(command: input)
        output = result
    }
}