import Foundation
import SwiftData

@Model
final class AIUsageRecord {
    @Attribute(.unique) var id: UUID
    var taskID: String
    var dateString: String
    var count: Int

    init(
        id: UUID = UUID(),
        taskID: String,
        dateString: String,
        count: Int = 1
    ) {
        self.id = id
        self.taskID = taskID
        self.dateString = dateString
        self.count = count
    }
}
