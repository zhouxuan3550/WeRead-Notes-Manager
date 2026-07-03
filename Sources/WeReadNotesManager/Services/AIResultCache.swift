import Foundation
import SwiftData

// MARK: - 缓存模型

@Model
final class AIGeneratedResult {
    @Attribute(.unique) var id: String
    var taskID: String
    var cacheKey: String
    var rawJSON: String
    var createdAt: Date

    init(taskID: String, cacheKey: String, rawJSON: String) {
        self.id = "\(taskID):\(cacheKey)"
        self.taskID = taskID
        self.cacheKey = cacheKey
        self.rawJSON = rawJSON
        self.createdAt = Date()
    }
}

// MARK: - 缓存服务

@MainActor
final class AIResultCache {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func load(taskID: String, key: String) -> String? {
        let id = "\(taskID):\(key)"
        let descriptor = FetchDescriptor<AIGeneratedResult>(predicate: #Predicate { $0.id == id })
        guard let result = try? context.fetch(descriptor).first else { return nil }
        return result.rawJSON
    }

    func save(taskID: String, key: String, raw: String) {
        let id = "\(taskID):\(key)"
        let descriptor = FetchDescriptor<AIGeneratedResult>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            existing.rawJSON = raw
            existing.createdAt = Date()
        } else {
            let result = AIGeneratedResult(taskID: taskID, cacheKey: key, rawJSON: raw)
            context.insert(result)
        }
        try? context.save()
    }

    func invalidate(taskID: String, key: String) {
        let id = "\(taskID):\(key)"
        let descriptor = FetchDescriptor<AIGeneratedResult>(predicate: #Predicate { $0.id == id })
        if let result = try? context.fetch(descriptor).first {
            context.delete(result)
            try? context.save()
        }
    }

    func invalidateAll(taskID: String) {
        let descriptor = FetchDescriptor<AIGeneratedResult>(predicate: #Predicate { $0.taskID == taskID })
        let results = (try? context.fetch(descriptor)) ?? []
        for result in results {
            context.delete(result)
        }
        if !results.isEmpty {
            try? context.save()
        }
    }
}
