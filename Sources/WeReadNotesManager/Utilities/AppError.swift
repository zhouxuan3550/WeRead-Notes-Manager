import Foundation
import os
import SwiftData

/// 统一的应用日志入口。
///
/// 用法：
/// ```swift
/// do {
///     try ctx.save()
/// } catch {
///     AppLog.error("保存失败", error: error)
/// }
/// ```
enum AppLog {
    private static let subsystem = "com.weread.notesmanager"
    private static let store = Logger(subsystem: subsystem, category: "general")
    private static let persistence = Logger(subsystem: subsystem, category: "persistence")
    private static let network = Logger(subsystem: subsystem, category: "network")
    private static let ai = Logger(subsystem: subsystem, category: "ai")
    private static let importer = Logger(subsystem: subsystem, category: "importer")

    static func error(_ message: String, error: Error? = nil, category: Category = .general) {
        let logger = logger(for: category)
        if let error {
            logger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("\(message, privacy: .public)")
        }
    }

    static func warn(_ message: String, category: Category = .general) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    static func info(_ message: String, category: Category = .general) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    static func debug(_ message: String, category: Category = .general) {
        logger(for: category).debug("\(message, privacy: .public)")
    }

    private static func logger(for category: Category) -> Logger {
        switch category {
        case .general: return store
        case .persistence: return persistence
        case .network: return network
        case .ai: return ai
        case .importer: return importer
        }
    }

    enum Category {
        case general
        case persistence
        case network
        case ai
        case importer
    }
}

/// 集中处理 SwiftData 写入错误：记录日志 + 返回安全默认值。
///
/// 用于替换 `try? context.save()` / `try? modelContext.fetch()` 模式。
enum SafePersistence {
    /// 安全保存：失败时记录日志，不抛出。
    @discardableResult
    static func save(_ context: ModelContext, label: String = "save") -> Bool {
        do {
            try context.save()
            return true
        } catch {
            AppLog.error("SwiftData \(label) 失败", error: error, category: .persistence)
            return false
        }
    }

    /// 安全 fetch：失败时返回空数组并记录日志。
    static func fetch<T>(_ context: ModelContext, _ descriptor: FetchDescriptor<T>, label: String = "fetch") -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            AppLog.error("SwiftData \(label) 失败", error: error, category: .persistence)
            return []
        }
    }

    /// 安全 fetch count：失败时返回 0。
    static func fetchCount<T>(_ context: ModelContext, _ descriptor: FetchDescriptor<T>, label: String = "fetchCount") -> Int {
        do {
            return try context.fetchCount(descriptor)
        } catch {
            AppLog.error("SwiftData \(label) 失败", error: error, category: .persistence)
            return 0
        }
    }
}
