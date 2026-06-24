import Foundation

enum SidebarItem: Hashable, CaseIterable, Identifiable {
    case dashboard
    case allNotes
    case todayReview
    case randomNotes
    case themeMap
    case readingReport
    case favorites
    case unreviewed
    case books
    case tags
    case askAI
    case trash
    case syncHistory
    case settings

    var id: String { label }

    var label: String {
        switch self {
        case .dashboard: return "首页"
        case .allNotes: return "搜索"
        case .todayReview: return "复习"
        case .randomNotes: return "随机笔记"
        case .themeMap: return "主题地图"
        case .readingReport: return "阅读报告"
        case .favorites: return "收藏"
        case .unreviewed: return "未复习"
        case .books: return "书籍"
        case .tags: return "标签"
        case .askAI: return "问 AI"
        case .trash: return "回收站"
        case .syncHistory: return "同步历史"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "house"
        case .allNotes: return "magnifyingglass"
        case .todayReview: return "rectangle.stack"
        case .randomNotes: return "shuffle"
        case .themeMap: return "point.3.connected.trianglepath.dotted"
        case .readingReport: return "doc.text.magnifyingglass"
        case .favorites: return "star"
        case .unreviewed: return "eye.slash"
        case .books: return "books.vertical"
        case .tags: return "tag"
        case .askAI: return "sparkles"
        case .trash: return "trash"
        case .syncHistory: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}
