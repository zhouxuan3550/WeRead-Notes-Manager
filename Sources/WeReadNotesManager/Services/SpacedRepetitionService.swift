import Foundation

/// 简化版 SM-2 间隔重复算法。
///
/// 每张卡片维护四个状态：
/// - `easeFactor`: 难度系数（默认 2.5，越低表示越难）
/// - `intervalDays`: 当前间隔（天）
/// - `repetitions`: 连续答对次数
/// - `nextReviewAt`: 下次到期时间
///
/// 4 档评级：
/// - `.again`: 完全忘了 → 重置 interval=1, reps=0, ease -= 0.2（最小 1.3）
/// - `.hard`:  答对但很费劲 → interval *= 1.2, ease -= 0.15
/// - `.good`: 正常答对 → 标准 SM-2 公式
/// - `.easy`: 轻松答对 → interval *= ease * 1.3，ease 不变（或 +0.05）
enum ReviewGrade: Int, CaseIterable, Identifiable {
    case again = 0
    case hard = 1
    case good = 2
    case easy = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .again: return "忘记了"
        case .hard: return "很费劲"
        case .good: return "想起来了"
        case .easy: return "很轻松"
        }
    }

    var systemImage: String {
        switch self {
        case .again: return "xmark.circle.fill"
        case .hard: return "minus.circle.fill"
        case .good: return "checkmark.circle.fill"
        case .easy: return "star.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .again: return "red"
        case .hard: return "orange"
        case .good: return "green"
        case .easy: return "blue"
        }
    }
}

struct SRSState {
    var easeFactor: Double
    var intervalDays: Int
    var repetitions: Int
    var nextReviewAt: Date?

    static let initial = SRSState(easeFactor: 2.5, intervalDays: 0, repetitions: 0, nextReviewAt: nil)

    /// 是否到期（nextReviewAt 为 nil 也算到期——从未复习过）
    var isDue: Bool {
        guard let nextReviewAt else { return true }
        return nextReviewAt <= Date()
    }
}

enum SpacedRepetitionService {
    /// 计算评分后的新状态（不修改原对象）。
    static func nextState(after grade: ReviewGrade, current: SRSState, now: Date = Date()) -> SRSState {
        var ease = current.easeFactor
        var interval = current.intervalDays
        var reps = current.repetitions

        switch grade {
        case .again:
            // 重置
            ease = max(1.3, ease - 0.2)
            interval = 1
            reps = 0
        case .hard:
            ease = max(1.3, ease - 0.15)
            // 第一次 hard 用 1 天；之后用 max(interval * 1.2, 1)
            interval = max(1, Int((Double(interval) * 1.2).rounded()))
            reps += 1
        case .good:
            // 标准 SM-2
            if reps == 0 {
                interval = 1
            } else if reps == 1 {
                interval = 6
            } else {
                interval = Int((Double(interval) * ease).rounded())
            }
            reps += 1
        case .easy:
            ease = min(3.5, ease + 0.05)
            // 直接拉长
            if reps == 0 {
                interval = 4
            } else {
                interval = Int((Double(interval) * ease * 1.3).rounded())
            }
            reps += 1
        }

        let next = now.addingTimeInterval(Double(interval) * 86400)
        return SRSState(easeFactor: ease, intervalDays: interval, repetitions: reps, nextReviewAt: next)
    }

    /// 把 SRSState 写回 ReadingNote。
    static func apply(_ state: SRSState, to note: ReadingNote, grade: ReviewGrade) {
        note.easeFactor = state.easeFactor
        note.intervalDays = state.intervalDays
        note.repetitions = state.repetitions
        note.nextReviewAt = state.nextReviewAt
        note.reviewCount += 1
        note.lastReviewedAt = Date()
        note.isReviewed = grade != .again
        note.updatedAt = Date()
    }

    /// 从现有 ReadingNote 字段读出 SRSState。
    static func currentState(of note: ReadingNote) -> SRSState {
        SRSState(
            easeFactor: note.easeFactor,
            intervalDays: note.intervalDays,
            repetitions: note.repetitions,
            nextReviewAt: note.nextReviewAt
        )
    }
}