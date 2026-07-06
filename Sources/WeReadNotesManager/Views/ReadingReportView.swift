import SwiftUI

struct ReadingReportView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if appVM.books.isEmpty {
                    ContentUnavailableView("还没有可生成报告的书", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    ForEach(reportBooks) { book in
                        BookReportCard(report: ReadingInsightService.bookReport(for: book))
                    }
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("阅读报告")
                .font(.system(size: 24, weight: .bold))
            Text("按书生成个人阅读档案，自动整理主题、密集章节和精选摘录。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var reportBooks: [Book] {
        appVM.books
            .filter { !$0.notes.isEmpty }
            .sorted { $0.notes.count > $1.notes.count }
    }
}

struct BookReportCard: View {
    let report: BookReadingReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                BookCoverView(book: report.book, size: .medium)
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.book.title)
                        .font(.system(size: 18, weight: .bold))
                    Text(report.book.author ?? "未知作者")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("\(report.noteCount) 条笔记 · \(report.thoughtCount) 条想法 · \(report.favoriteCount) 条收藏")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if !report.themes.isEmpty {
                FlowTags(tags: report.themes)
            }

            if !report.topChapters.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("高密度章节")
                        .font(.system(size: 13, weight: .semibold))
                    ForEach(report.topChapters, id: \.title) { item in
                        HStack {
                            Text(item.title)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.count)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 12))
                    }
                }
            }

            if let note = report.featuredNotes.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("精选摘录")
                        .font(.system(size: 13, weight: .semibold))
                    Text(note.highlight)
                        .font(.system(size: 13))
                        .lineLimit(4)
                }
            }
        }
        .padding(16)
        .glassPanel()
    }
}

struct FlowTags: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .appBadgeSurface()
            }
        }
    }
}
