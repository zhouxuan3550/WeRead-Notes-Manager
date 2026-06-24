import SwiftUI
import SwiftData

struct StatsDashboardView: View {
    @Environment(AppViewModel.self) private var appVM
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    statCard(
                        title: "书籍总数",
                        value: "\(appVM.books.count)",
                        icon: "books.vertical",
                        color: .blue
                    )
                    statCard(
                        title: "笔记总数",
                        value: "\(appVM.allNotes.count)",
                        icon: "note.text",
                        color: .green
                    )
                    statCard(
                        title: "想法数量",
                        value: "\(appVM.libraryStats.thoughtCount)",
                        icon: "quote.bubble",
                        color: .orange
                    )
                    statCard(
                        title: "待复习",
                        value: "\(appVM.dueNotes.count)",
                        icon: "clock",
                        color: .red
                    )
                }
                
                Divider()
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    reviewProgressCard
                    favoritesCard
                    weeklyActivityCard
                    topBooksCard
                }
            }
            .padding(24)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("统计仪表盘")
                .font(.system(size: 24, weight: .bold))
            Text("全面了解你的阅读笔记、复习进度和知识积累。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .bold))
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassPanel()
    }
    
    private var reviewProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("复习进度")
                .font(.system(size: 16, weight: .semibold))
            
            HStack(spacing: 16) {
                progressCircle(
                    value: appVM.libraryStats.unreviewedCount,
                    total: appVM.allNotes.count,
                    color: .green,
                    label: "已复习"
                )
                progressCircle(
                    value: appVM.dueNotes.count,
                    total: appVM.allNotes.count,
                    color: .orange,
                    label: "待复习"
                )
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("SRS 分布")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach([0, 1, 2, 3, 4, 5], id: \.self) { level in
                        let count = appVM.allNotes.filter { $0.repetitions == level }.count
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.3 + Double(level) * 0.1))
                                .frame(width: 24, height: max(CGFloat(count) * 2, 4))
                            Text("\(level)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text("\(count)")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .glassPanel()
    }
    
    private func progressCircle(value: Int, total: Int, color: Color, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: total > 0 ? Double(value) / Double(total) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(value)")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(width: 60, height: 60)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
    
    private var favoritesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("收藏与精选")
                .font(.system(size: 16, weight: .semibold))
            
            let favoriteCount = appVM.allNotes.filter { $0.isFavorite }.count
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(favoriteCount)")
                        .font(.system(size: 24, weight: .bold))
                    Text("收藏笔记")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "star.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.yellow)
            }
            
            Divider()
            
            if let topBook = appVM.books.max(by: { $0.notes.count < $1.notes.count }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("笔记最多")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(topBook.title)
                        .font(.system(size: 13))
                        .lineLimit(2)
                    Text("\(topBook.notes.count) 条笔记")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .glassPanel()
    }
    
    private var weeklyActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("近期活动")
                .font(.system(size: 16, weight: .semibold))
            
            let calendar = Calendar.current
            let today = Date()
            let last7Days = (0..<7).map { i -> Date in
                calendar.date(byAdding: .day, value: -i, to: today)!
            }.reversed()
            
            HStack(spacing: 8) {
                ForEach(Array(last7Days.enumerated()), id: \.offset) { i, date in
                    let dayNotes = appVM.allNotes.filter { note in
                        let noteDate = note.createdAt ?? note.importedAt
                        return calendar.isDate(noteDate, inSameDayAs: date)
                    }
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple.opacity(0.3 + Double(min(dayNotes.count, 10)) * 0.05))
                            .frame(width: 24, height: max(CGFloat(dayNotes.count) * 3, 4))
                        Text(dateFormatter.string(from: date))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            let recentCount = appVM.allNotes.filter { note in
                let date = note.createdAt ?? note.importedAt
                return date > Date().addingTimeInterval(-7 * 86400)
            }.count

            Text("过去 7 天共 \(recentCount) 条新笔记")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassPanel()
    }
    
    private var topBooksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top 书籍")
                .font(.system(size: 16, weight: .semibold))
            
            let topBooks = appVM.books
                .filter { !$0.notes.isEmpty }
                .sorted { $0.notes.count > $1.notes.count }
                .prefix(5)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(topBooks.enumerated()), id: \.offset) { index, book in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        
                        BookCoverView(book: book, size: .small)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text("\(book.notes.count) 条笔记")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .glassPanel()
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
}
