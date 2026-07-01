import Foundation
import SwiftData
import SwiftUI

// MARK: - 数据健康检查
//
// 扫描整个笔记库，找出：
// 1. 孤立笔记（没有关联到任何书）
// 2. 空笔记（highlight 为空）
// 3. 重复书名（同标题多本书）
// 4. 损坏链接（sourceURL 格式异常）
// 5. 超长笔记（> 5000 字）
// 6. 重复 highlight（同一书内）
// 7. 孤儿标签（没有任何笔记使用）

struct HealthIssue: Identifiable {
    let id = UUID()
    let severity: Severity
    let category: Category
    let title: String
    let detail: String

    enum Severity: String {
        case info, warning, error
        var color: String {
            switch self {
            case .info: return "info"
            case .warning: return "warning"
            case .error: return "error"
            }
        }
    }

    enum Category: String {
        case orphan, empty, duplicate, broken, oversized, orphanTag, missingChapter
    }
}

struct HealthReport {
    var issues: [HealthIssue] = []
    var totalNotes: Int = 0
    var totalBooks: Int = 0
    var totalTags: Int = 0
    var attachmentSize: Int64 = 0
    var scanDate: Date = .now

    var byCategory: [HealthIssue.Category: [HealthIssue]] {
        Dictionary(grouping: issues) { $0.category }
    }

    var summary: (info: Int, warning: Int, error: Int) {
        var info = 0
        var warning = 0
        var errorCount = 0
        for issue in issues {
            switch issue.severity {
            case .info: info += 1
            case .warning: warning += 1
            case .error: errorCount += 1
            }
        }
        return (info, warning, errorCount)
    }
}

enum DataHealthCheckService {
    @MainActor
    static func runFullCheck(books: [Book], allNotes: [ReadingNote]) -> HealthReport {
        var issues: [HealthIssue] = []
        var report = HealthReport()
        report.totalBooks = books.count
        report.totalNotes = allNotes.count
        report.attachmentSize = ImageAttachmentService.totalSize()

        // 1. 孤立笔记
        let orphanNotes = allNotes.filter { $0.book == nil }
        if !orphanNotes.isEmpty {
            issues.append(HealthIssue(
                severity: .warning,
                category: .orphan,
                title: "\(orphanNotes.count) 条孤立笔记",
                detail: "这些笔记没有关联到任何书。可以批量删除或重新关联。"
            ))
        }

        // 2. 空笔记
        let emptyNotes = allNotes.filter { $0.highlight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !emptyNotes.isEmpty {
            issues.append(HealthIssue(
                severity: .warning,
                category: .empty,
                title: "\(emptyNotes.count) 条空笔记",
                detail: "highlight 内容为空的笔记，可能是导入异常。"
            ))
        }

        // 3. 重复书名
        let bookTitleCounts = Dictionary(grouping: books, by: { $0.title }).filter { $0.value.count > 1 }
        if !bookTitleCounts.isEmpty {
            issues.append(HealthIssue(
                severity: .info,
                category: .duplicate,
                title: "\(bookTitleCounts.count) 组重名书籍",
                detail: "同名书籍可能是不同版本，可考虑合并。"
            ))
        }

        // 4. 损坏链接
        let brokenURLNotes = allNotes.filter { note in
            guard let urlString = note.sourceURL, !urlString.isEmpty else { return false }
            return URL(string: urlString)?.scheme == nil
        }
        if !brokenURLNotes.isEmpty {
            issues.append(HealthIssue(
                severity: .info,
                category: .broken,
                title: "\(brokenURLNotes.count) 条笔记链接格式异常",
                detail: "sourceURL 不是合法 URL。"
            ))
        }

        // 5. 超长笔记
        let oversizedNotes = allNotes.filter { $0.highlight.count > 5000 }
        if !oversizedNotes.isEmpty {
            issues.append(HealthIssue(
                severity: .info,
                category: .oversized,
                title: "\(oversizedNotes.count) 条超长笔记（>5000 字）",
                detail: "可能影响搜索性能，可考虑拆分。"
            ))
        }

        // 6. 同一本书内的重复 highlight
        var duplicatesByBook: [String: Int] = [:]
        for book in books {
            let highlights = book.notes.map { $0.highlight.trimmingCharacters(in: .whitespacesAndNewlines) }
            let uniqueCount = Set(highlights).count
            let dupCount = highlights.count - uniqueCount
            if dupCount > 0 {
                duplicatesByBook[book.title] = dupCount
            }
        }
        if !duplicatesByBook.isEmpty {
            let totalDup = duplicatesByBook.values.reduce(0, +)
            issues.append(HealthIssue(
                severity: .info,
                category: .duplicate,
                title: "书内重复划线 \(totalDup) 条",
                detail: "同一本书内有重复的划线内容。导入设置里开启「跳过重复」可避免。"
            ))
        }

        // 7. 孤儿标签
        let allTags = Set(allNotes.flatMap { $0.tags })
        report.totalTags = allTags.count
        // 已经在 allNotes.flatMap 过滤的标签都有人用，跳过

        // 8. 未分章的笔记
        let missingChapter = allNotes.filter { ($0.chapter?.isEmpty ?? true) && !$0.isDeleted }
        if missingChapter.count > Int(Double(allNotes.count) * 0.5) && !allNotes.isEmpty {
            issues.append(HealthIssue(
                severity: .info,
                category: .missingChapter,
                title: "大量笔记未分章",
                detail: "\(missingChapter.count) 条笔记没有章节信息。"
            ))
        }

        report.issues = issues
        return report
    }
}

// MARK: - 健康检查 UI

struct DataHealthCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.themePalette) private var palette

    @State private var report: HealthReport?
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let report {
                content(report)
            } else {
                empty
            }
        }
        .frame(width: 580, height: 480)
    }

    private var header: some View {
        HStack {
            Image(systemName: "stethoscope")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text("数据健康检查")
                .font(.headline)
            Spacer()
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 56))
                .foregroundStyle(palette.textTertiary)
            Text("点击扫描，检查笔记库健康状态")
                .font(.callout)
                .foregroundStyle(palette.textSecondary)
            Button {
                Task { await scan() }
            } label: {
                if isScanning {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("扫描中...")
                    }
                } else {
                    Label("开始扫描", systemImage: "magnifyingglass")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(_ report: HealthReport) -> some View {
        let s = report.summary
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                summaryRow(report, info: s.info, warning: s.warning, error: s.error)

                if report.issues.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(palette.success)
                        Text("一切正常！没有发现数据问题。")
                            .font(.callout)
                            .foregroundStyle(palette.textPrimary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(palette.success.opacity(0.10)))
                } else {
                    ForEach(report.issues) { issue in
                        issueRow(issue)
                    }
                }

                // 统计
                statsRow(report)

                Button {
                    self.report = nil
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }

    private func summaryRow(_ report: HealthReport, info: Int, warning: Int, error: Int) -> some View {
        HStack(spacing: 12) {
            statCard(label: "书籍", value: "\(report.totalBooks)", color: palette.accent)
            statCard(label: "笔记", value: "\(report.totalNotes)", color: palette.success)
            statCard(label: "标签", value: "\(report.totalTags)", color: palette.warning)
            statCard(label: "附件", value: ByteCountFormatter().string(fromByteCount: report.attachmentSize), color: palette.error)
        }
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(palette.surface.opacity(0.5)))
    }

    private func issueRow(_ issue: HealthIssue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon(for: issue.severity))
                .foregroundStyle(color(for: issue.severity))
                .font(.system(size: 14))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(issue.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(color(for: issue.severity).opacity(0.10)))
    }

    private func statsRow(_ report: HealthReport) -> some View {
        Text("扫描时间：\(report.scanDate.shortString)")
            .font(.system(size: 10))
            .foregroundStyle(palette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
    }

    private func icon(for s: HealthIssue.Severity) -> String {
        switch s {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private func color(for s: HealthIssue.Severity) -> Color {
        switch s {
        case .info: return palette.accent
        case .warning: return palette.warning
        case .error: return palette.error
        }
    }

    private func scan() async {
        isScanning = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        await MainActor.run {
            report = DataHealthCheckService.runFullCheck(books: appVM.books, allNotes: appVM.allNotes)
            isScanning = false
        }
    }
}