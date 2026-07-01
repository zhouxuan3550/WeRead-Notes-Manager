import Foundation
import SwiftUI

// MARK: - 搜索历史 + 建议
//
// - 保存最近 30 次搜索
// - 自动去重（相同搜索只保留最新时间）
// - 按时间倒序
// - 提供"清空"动作
// - 异步建议：基于笔记库里出现过的关键词

@MainActor
@Observable
final class SearchHistoryStore {
    static let shared = SearchHistoryStore()

    var entries: [String] = []
    private let maxCount = 30
    private let defaults = UserDefaults.standard
    private let key = "searchHistory"

    private init() {
        entries = defaults.stringArray(forKey: key) ?? []
    }

    func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        entries.removeAll { $0 == trimmed }
        entries.insert(trimmed, at: 0)
        if entries.count > maxCount {
            entries = Array(entries.prefix(maxCount))
        }
        defaults.set(entries, forKey: key)
    }

    func clear() {
        entries = []
        defaults.removeObject(forKey: key)
    }

    func remove(_ query: String) {
        entries.removeAll { $0 == query }
        defaults.set(entries, forKey: key)
    }
}

// MARK: - 搜索建议提供者

enum SearchSuggestionProvider {
    /// 从笔记库里提取建议（标签、作者、关键词）
    static func suggestions(for prefix: String, in books: [Book]) -> [String] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lower = trimmed.lowercased()
        var candidates = Set<String>()

        // 1. 书名
        for book in books {
            if book.title.lowercased().contains(lower) {
                candidates.insert(book.title)
            }
            if let author = book.author, author.lowercased().contains(lower) {
                candidates.insert(author)
            }
        }

        // 2. 标签
        for book in books {
            for note in book.notes {
                for tag in note.tags {
                    if tag.name.lowercased().contains(lower) {
                        candidates.insert("#\(tag.name)")
                    }
                }
            }
        }

        return Array(candidates.prefix(8)).sorted()
    }
}

// MARK: - 搜索建议 UI

struct SearchSuggestionList: View {
    let suggestions: [String]
    let history: [String]
    let onSelect: (String) -> Void
    let onRemove: (String) -> Void
    let onClearHistory: () -> Void

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !suggestions.isEmpty {
                sectionTitle("建议")
                ForEach(suggestions, id: \.self) { s in
                    row(s, icon: "sparkles") { onSelect(s) }
                }
            }

            if !history.isEmpty {
                HStack {
                    sectionTitle("最近搜索")
                    Spacer()
                    Button("清空", action: onClearHistory)
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(palette.textTertiary)
                }
                ForEach(history.prefix(8), id: \.self) { h in
                    HStack {
                        row(h, icon: "clock.arrow.circlepath") { onSelect(h) }
                        Spacer()
                        Button {
                            onRemove(h)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.textTertiary)
                        .padding(.trailing, 6)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.borderMedium, lineWidth: 0.5)
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(palette.textTertiary)
            .padding(.horizontal, 6)
    }

    private func row(_ text: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: 14)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}