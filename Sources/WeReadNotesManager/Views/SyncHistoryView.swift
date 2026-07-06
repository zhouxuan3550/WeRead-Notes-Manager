import SwiftData
import SwiftUI

struct SyncHistoryView: View {
    @Query(sort: \ImportRecord.importedAt, order: .reverse) private var records: [ImportRecord]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if records.isEmpty {
                ContentUnavailableView("暂无同步历史", systemImage: "clock.arrow.circlepath", description: Text("同步微信读书或导入文件后会自动记录"))
            } else {
                List(records) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(record.sourceDisplayName, systemImage: record.source == "weread_skill" ? "sparkles" : "doc.text")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(record.importedAt.shortString)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Text(record.fileName)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            metric("新增", record.notesCreated, .green)
                            metric("重复", record.duplicatesSkipped, .orange)
                            metric("失败", record.failedCount, record.failedCount > 0 ? .red : .secondary)
                            metric("新书", record.booksCreated, .blue)
                        }
                        if let message = record.message, !message.isEmpty {
                            Text(message)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.inset)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("同步历史")
                    .font(.system(size: 20, weight: .semibold))
                Text("查看每次微信读书同步和文件导入结果")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func metric(_ title: String, _ value: Int, _ color: Color) -> some View {
        Text("\(title) \(value)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .appBadgeSurface()
    }
}

private extension ImportRecord {
    var sourceDisplayName: String {
        switch source {
        case "weread_skill": return "微信读书同步"
        case "markdown": return "Markdown 导入"
        case "txt": return "TXT 导入"
        default: return source
        }
    }
}
