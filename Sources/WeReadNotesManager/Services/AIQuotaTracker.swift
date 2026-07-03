import Foundation
import SwiftUI

// MARK: - 配额管理

/// 追踪 AI 调用配额，用于 Free/Pro 分层。
@MainActor
final class AIQuotaTracker {
    @AppStorage("aiCallsToday") private var callsToday: Int = 0
    @AppStorage("aiCallsResetDate") private var resetDate: String = ""
    @AppStorage("isProUser") private var isProUser: Bool = false

    var dailyLimit: Int = 10 // 免费层每日上限

    func consume(taskID: String) -> Bool {
        resetIfNeeded()
        if isProUser { return true }
        guard callsToday < dailyLimit else { return false }
        callsToday += 1
        return true
    }

    var remainingCalls: Int {
        resetIfNeeded()
        return isProUser ? Int.max : max(0, dailyLimit - callsToday)
    }

    var isLimitReached: Bool {
        !isProUser && callsToday >= dailyLimit
    }

    private func resetIfNeeded() {
        let today = Date().quotaDayString
        if resetDate != today {
            resetDate = today
            callsToday = 0
        }
    }
}
