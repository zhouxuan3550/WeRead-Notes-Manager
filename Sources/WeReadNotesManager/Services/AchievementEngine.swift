import Foundation
import SwiftUI

// MARK: - 成就系统
//
// 用户达到某些里程碑时解锁徽章 + 经验值：
// - 阅读笔记 1/10/50/100/500/1000 条
// - 连续打卡 7/30/100/365 天
// - 收藏 10/50/200 条
// - 复习 100/500/2000 次
// - 写作助手生成 1/10/50 篇
// - 阅读完 1/10/50 本书
// - ...
//
// 数据存 UserDefaults + JSON（记录解锁时间、进度）
// 解锁动画 + 通知

// MARK: - 成就定义

struct Achievement: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var description: String
    var icon: String
    var tier: Tier
    var category: Category
    var requirement: Int  // 触发阈值
    var xpReward: Int

    enum Tier: String, Codable {
        case bronze, silver, gold, platinum

        var color: String {
            switch self {
            case .bronze: return "#CD7F32"
            case .silver: return "#C0C0C0"
            case .gold: return "#FFD700"
            case .platinum: return "#E5E4E2"
            }
        }

        var displayName: String {
            switch self {
            case .bronze: return "铜"
            case .silver: return "银"
            case .gold: return "金"
            case .platinum: return "铂金"
            }
        }
    }

    enum Category: String, Codable {
        case noteCount, streak, favorite, review, writing, bookCount, tagCount

        var displayName: String {
            switch self {
            case .noteCount: return "笔记"
            case .streak: return "连续"
            case .favorite: return "收藏"
            case .review: return "复习"
            case .writing: return "写作"
            case .bookCount: return "书籍"
            case .tagCount: return "标签"
            }
        }
    }
}

// MARK: - 用户进度

struct UserProgress: Codable {
    var unlockedIDs: Set<String> = []
    var unlockedDates: [String: Date] = [:]
    var streakDays: Int = 0
    var longestStreak: Int = 0
    var lastActivityDate: Date?
    var totalXP: Int = 0
    var level: Int = 1
}

// MARK: - 成就管理器

@MainActor
@Observable
final class AchievementEngine {
    static let shared = AchievementEngine()

    var progress: UserProgress = AchievementEngine.loadProgress()
    var newlyUnlocked: Achievement?
    var showingCelebration = false

    private init() {}

    static let allAchievements: [Achievement] = [
        // 笔记数量
        Achievement(id: "n1", title: "第一笔", description: "记录你的第一条笔记", icon: "pencil.tip", tier: .bronze, category: .noteCount, requirement: 1, xpReward: 10),
        Achievement(id: "n10", title: "笔记新手", description: "累计 10 条笔记", icon: "doc.text", tier: .bronze, category: .noteCount, requirement: 10, xpReward: 30),
        Achievement(id: "n50", title: "勤勉记录", description: "累计 50 条笔记", icon: "doc.text.fill", tier: .silver, category: .noteCount, requirement: 50, xpReward: 80),
        Achievement(id: "n100", title: "笔记达人", description: "累计 100 条笔记", icon: "books.vertical", tier: .silver, category: .noteCount, requirement: 100, xpReward: 150),
        Achievement(id: "n500", title: "笔记大师", description: "累计 500 条笔记", icon: "books.vertical.fill", tier: .gold, category: .noteCount, requirement: 500, xpReward: 400),
        Achievement(id: "n1000", title: "笔记传奇", description: "累计 1000 条笔记", icon: "star.circle.fill", tier: .platinum, category: .noteCount, requirement: 1000, xpReward: 1000),

        // Streak
        Achievement(id: "s7", title: "坚持一周", description: "连续 7 天有阅读活动", icon: "flame.fill", tier: .bronze, category: .streak, requirement: 7, xpReward: 50),
        Achievement(id: "s30", title: "一月常客", description: "连续 30 天有阅读活动", icon: "flame.circle.fill", tier: .silver, category: .streak, requirement: 30, xpReward: 200),
        Achievement(id: "s100", title: "百日精进", description: "连续 100 天有阅读活动", icon: "flame", tier: .gold, category: .streak, requirement: 100, xpReward: 500),
        Achievement(id: "s365", title: "年度阅读者", description: "连续 365 天有阅读活动", icon: "trophy.fill", tier: .platinum, category: .streak, requirement: 365, xpReward: 2000),

        // 复习
        Achievement(id: "r100", title: "复习入门", description: "复习 100 次", icon: "checkmark.circle", tier: .bronze, category: .review, requirement: 100, xpReward: 50),
        Achievement(id: "r500", title: "复习专家", description: "复习 500 次", icon: "checkmark.circle.fill", tier: .silver, category: .review, requirement: 500, xpReward: 200),
        Achievement(id: "r2000", title: "复习大师", description: "复习 2000 次", icon: "graduationcap.fill", tier: .gold, category: .review, requirement: 2000, xpReward: 800),

        // 收藏
        Achievement(id: "f10", title: "初识珍宝", description: "收藏 10 条笔记", icon: "star", tier: .bronze, category: .favorite, requirement: 10, xpReward: 20),
        Achievement(id: "f50", title: "珍藏家", description: "收藏 50 条笔记", icon: "star.fill", tier: .silver, category: .favorite, requirement: 50, xpReward: 100),
        Achievement(id: "f200", title: "金句收藏家", description: "收藏 200 条笔记", icon: "star.circle.fill", tier: .gold, category: .favorite, requirement: 200, xpReward: 400),

        // 写作
        Achievement(id: "w1", title: "AI 写作首篇", description: "用 AI 写作助手生成第 1 篇文章", icon: "wand.and.stars", tier: .bronze, category: .writing, requirement: 1, xpReward: 20),
        Achievement(id: "w10", title: "小有所成", description: "AI 写作 10 篇", icon: "wand.and.rays", tier: .silver, category: .writing, requirement: 10, xpReward: 100),
        Achievement(id: "w50", title: "写作大师", description: "AI 写作 50 篇", icon: "sparkles", tier: .gold, category: .writing, requirement: 50, xpReward: 500),

        // 书籍
        Achievement(id: "b1", title: "第一本", description: "读完第一本书", icon: "book", tier: .bronze, category: .bookCount, requirement: 1, xpReward: 30),
        Achievement(id: "b10", title: "小藏书家", description: "读完 10 本书", icon: "books.vertical", tier: .silver, category: .bookCount, requirement: 10, xpReward: 150),
        Achievement(id: "b50", title: "博览群书", description: "读完 50 本书", icon: "books.vertical.fill", tier: .gold, category: .bookCount, requirement: 50, xpReward: 600),

        // 标签
        Achievement(id: "t10", title: "标签新手", description: "创建 10 个标签", icon: "tag", tier: .bronze, category: .tagCount, requirement: 10, xpReward: 30),
        Achievement(id: "t50", title: "分类达人", description: "创建 50 个标签", icon: "tag.fill", tier: .silver, category: .tagCount, requirement: 50, xpReward: 150),
    ]

    // MARK: - 进度追踪

    func recordNoteCount(_ count: Int) {
        checkAchievements(category: .noteCount, value: count)
    }

    func recordFavoriteCount(_ count: Int) {
        checkAchievements(category: .favorite, value: count)
    }

    func recordReviewCount(_ count: Int) {
        checkAchievements(category: .review, value: count)
    }

    func recordWritingCount(_ count: Int) {
        checkAchievements(category: .writing, value: count)
    }

    func recordBookCount(_ count: Int) {
        checkAchievements(category: .bookCount, value: count)
    }

    func recordTagCount(_ count: Int) {
        checkAchievements(category: .tagCount, value: count)
    }

    /// 每天第一次活动时调用，更新 streak
    func recordDailyActivity() {
        let today = Calendar.current.startOfDay(for: Date())

        if let last = progress.lastActivityDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            let dayDiff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if dayDiff == 0 {
                return  // 今天已经记录过
            } else if dayDiff == 1 {
                progress.streakDays += 1  // 连续
            } else {
                progress.streakDays = 1  // 中断
            }
        } else {
            progress.streakDays = 1
        }

        progress.longestStreak = max(progress.longestStreak, progress.streakDays)
        progress.lastActivityDate = today

        checkAchievements(category: .streak, value: progress.streakDays)
        save()
    }

    // MARK: - 检查成就

    private func checkAchievements(category: Achievement.Category, value: Int) {
        let candidates = AchievementEngine.allAchievements.filter {
            $0.category == category && !progress.unlockedIDs.contains($0.id)
        }

        for achievement in candidates where value >= achievement.requirement {
            unlock(achievement)
        }
    }

    private func unlock(_ achievement: Achievement) {
        progress.unlockedIDs.insert(achievement.id)
        progress.unlockedDates[achievement.id] = Date()
        progress.totalXP += achievement.xpReward

        // 升级（每 500 XP 一级）
        progress.level = 1 + progress.totalXP / 500

        newlyUnlocked = achievement
        showingCelebration = true
        save()
    }

    func dismissCelebration() {
        showingCelebration = false
        newlyUnlocked = nil
    }

    // MARK: - 统计

    func progress(for achievement: Achievement, currentValue: Int) -> Double {
        min(1.0, Double(currentValue) / Double(achievement.requirement))
    }

    var unlockedCount: Int { progress.unlockedIDs.count }
    var totalCount: Int { AchievementEngine.allAchievements.count }

    // MARK: - 持久化

    private static func fileURL() -> URL {
        AppStoragePaths.file("achievements.json")
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        try? data.write(to: Self.fileURL(), options: .atomic)
    }

    private static func load() -> UserProgress {
        loadProgress()
    }

    static func loadProgress() -> UserProgress {
        guard let data = try? Data(contentsOf: fileURL()),
              let progress = try? JSONDecoder().decode(UserProgress.self, from: data) else {
            return UserProgress()
        }
        return progress
    }
}

// MARK: - 成就墙视图

struct AchievementWall: View {
    @State private var engine = AchievementEngine.shared
    @State private var selectedCategory: Achievement.Category?

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(spacing: 16) {
            // 顶部 stats
            statsHeader

            // 分类筛选
            categoryFilter

            // 网格
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 12)], spacing: 12) {
                    ForEach(displayedAchievements) { achievement in
                        AchievementBadge(
                            achievement: achievement,
                            isUnlocked: engine.progress.unlockedIDs.contains(achievement.id),
                            unlockDate: engine.progress.unlockedDates[achievement.id],
                            progress: engine.progress(for: achievement, currentValue: currentValue(for: achievement))
                        )
                    }
                }
                .padding(16)
            }
        }
        .overlay {
            if engine.showingCelebration, let ach = engine.newlyUnlocked {
                CelebrationOverlay(achievement: ach) {
                    engine.dismissCelebration()
                }
            }
        }
        .background(AmbientBackground(showGlows: true, showNoise: true))
    }

    private var displayedAchievements: [Achievement] {
        if let cat = selectedCategory {
            return AchievementEngine.allAchievements.filter { $0.category == cat }
        }
        return AchievementEngine.allAchievements
    }

    private func currentValue(for achievement: Achievement) -> Int {
        // 简化：从 AppStorage 读
        switch achievement.category {
        case .noteCount: return UserDefaults.standard.integer(forKey: "stats.totalNotes")
        case .streak: return engine.progress.streakDays
        case .favorite: return UserDefaults.standard.integer(forKey: "stats.totalFavorites")
        case .review: return UserDefaults.standard.integer(forKey: "stats.totalReviews")
        case .writing: return UserDefaults.standard.integer(forKey: "stats.totalWritings")
        case .bookCount: return UserDefaults.standard.integer(forKey: "stats.totalBooks")
        case .tagCount: return UserDefaults.standard.integer(forKey: "stats.totalTags")
        }
    }

    // MARK: - 顶部

    private var statsHeader: some View {
        HStack(spacing: 16) {
            levelCard
            streakCard
            xpCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var levelCard: some View {
        VStack(spacing: 4) {
            Text("Lv \(engine.progress.level)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(palette.accent)
            Text("等级")
                .font(Typography.micro)
                .tracking(0.6)
                .foregroundStyle(palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var streakCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                AnimatedNumber(
                    targetValue: engine.progress.streakDays,
                    font: .system(size: 28, weight: .bold, design: .rounded).monospacedDigit(),
                    color: palette.textPrimary
                )
            }
            Text("连续天数")
                .font(Typography.micro)
                .tracking(0.6)
                .foregroundStyle(palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surface.opacity(0.5))
        )
    }

    private var xpCard: some View {
        VStack(spacing: 4) {
            AnimatedNumber(
                targetValue: engine.progress.totalXP,
                font: .system(size: 28, weight: .bold, design: .rounded).monospacedDigit(),
                color: palette.warning
            )
            Text("经验值")
                .font(Typography.micro)
                .tracking(0.6)
                .foregroundStyle(palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surface.opacity(0.5))
        )
    }

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(label: "全部", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach([
                    Achievement.Category.noteCount,
                    .streak,
                    .review,
                    .favorite,
                    .writing,
                    .bookCount,
                    .tagCount
                ], id: \.self) { cat in
                    CategoryChip(label: cat.displayName, isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - 分类 Chip

struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.themePalette) private var palette

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typography.captionStrong)
                .foregroundStyle(isSelected ? palette.accent : palette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? palette.accentSoft : palette.surface.opacity(0.4))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? palette.accent.opacity(0.4) : palette.borderSubtle, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 成就徽章

struct AchievementBadge: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let unlockDate: Date?
    let progress: Double

    @Environment(\.themePalette) private var palette
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // 背景圆
                Circle()
                    .fill(badgeBackground)
                    .frame(width: 60, height: 60)
                    .shadow(color: isUnlocked ? tierColor.opacity(0.4) : .clear, radius: 12)

                // 进度环
                Circle()
                    .stroke(palette.borderSubtle.opacity(0.4), lineWidth: 2)
                    .frame(width: 64, height: 64)

                if progress > 0 && !isUnlocked {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                }

                // 图标
                Image(systemName: isUnlocked ? achievement.icon : "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isUnlocked ? tierColor : palette.textTertiary)
            }

            // 标题
            Text(achievement.title)
                .font(Typography.captionStrong)
                .foregroundStyle(isUnlocked ? palette.textPrimary : palette.textTertiary)
                .lineLimit(1)

            // tier 标签
            Text(achievement.tier.displayName)
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Capsule().fill(tierColor.opacity(0.2)))
                .foregroundStyle(tierColor)

            // XP
            Text("+\(achievement.xpReward) XP")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(palette.textTertiary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surface.opacity(isUnlocked ? 0.6 : 0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUnlocked ? tierColor.opacity(0.4) : palette.borderSubtle, lineWidth: 0.5)
        )
        .scaleEffect(hovering ? 1.05 : 1)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
    }

    private var badgeBackground: Color {
        if isUnlocked {
            return tierColor.opacity(0.15)
        }
        return palette.surfaceElevated.opacity(0.4)
    }

    private var tierColor: Color {
        Color(hex: achievement.tier.color) ?? palette.accent
    }
}

// MARK: - 解锁动画

struct CelebrationOverlay: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.3
    @State private var rotation: Double = -30
    @State private var opacity: Double = 0
    @Environment(\.themePalette) private var palette

    var body: some View {
        ZStack {
            palette.background.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    ForEach(0..<8) { i in
                        Circle()
                            .stroke(tierColor.opacity(0.3), lineWidth: 1)
                            .frame(width: CGFloat(80 + i * 30), height: CGFloat(80 + i * 30))
                            .scaleEffect(scale)
                            .opacity(1 - Double(i) * 0.12)
                    }

                    ZStack {
                        Circle()
                            .fill(tierColor.opacity(0.2))
                            .frame(width: 120, height: 120)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [tierColor.opacity(0.5), Color.clear],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: achievement.icon)
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(tierColor)
                            .shadow(color: tierColor.opacity(0.5), radius: 16)
                    }
                    .rotationEffect(.degrees(rotation))
                }

                VStack(spacing: 8) {
                    Text("成就解锁！")
                        .font(Typography.captionStrong)
                        .tracking(2)
                        .foregroundStyle(tierColor)
                        .textCase(.uppercase)

                    Text(achievement.title)
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(palette.textPrimary)

                    Text(achievement.description)
                        .font(Typography.body)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("+\(achievement.xpReward) XP")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(tierColor.opacity(0.18)))
                        .foregroundStyle(tierColor)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.5), radius: 30)
            )
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                rotation = 0
                opacity = 1
            }
        }
        .onTapGesture {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 0
                scale = 0.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDismiss()
            }
        }
    }

    private var tierColor: Color {
        Color(hex: achievement.tier.color) ?? palette.accent
    }
}
