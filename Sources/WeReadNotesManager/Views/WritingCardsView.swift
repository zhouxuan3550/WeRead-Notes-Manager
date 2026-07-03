import SwiftUI
import SwiftData
import AppKit

/// 写作素材卡库：浏览、复制、导出所有生成的素材卡。
struct WritingCardsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themePalette) private var palette
    @Query(sort: \WritingCard.createdAt, order: .reverse) private var cards: [WritingCard]

    @State private var selectedCard: WritingCard?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                cardList
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
                Divider()
                cardDetail
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("写作素材卡")
                    .font(.system(size: 20, weight: .semibold))
                Text("从书摘扩展出的可引用写作素材")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(filteredCards.count) 张")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var filteredCards: [WritingCard] {
        if searchText.isEmpty { return cards }
        return cards.filter {
            $0.coreIdea.localizedCaseInsensitiveContains(searchText) ||
            $0.highlight.localizedCaseInsensitiveContains(searchText) ||
            ($0.bookTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var cardList: some View {
        List(selection: $selectedCard) {
            if filteredCards.isEmpty {
                ContentUnavailableView(
                    "还没有素材卡",
                    systemImage: "rectangle.stack",
                    description: Text("在笔记详情页点击“生成素材卡”创建")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredCards) { card in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.coreIdea)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Text(card.bookTitle ?? "未知书籍")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text(card.createdAt.shortString)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(card)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var cardDetail: some View {
        ScrollView {
            if let card = selectedCard ?? cards.first {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.coreIdea)
                                .font(.system(size: 20, weight: .bold))
                            if let bookTitle = card.bookTitle {
                                Text("《\(bookTitle)》")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            copyCard(card)
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .flatActionButton(.secondary, height: 32)

                        Button {
                            exportMarkdown(card)
                        } label: {
                            Label("导出", systemImage: "square.and.arrow.up")
                        }
                        .flatActionButton(.accent, height: 32)
                    }

                    cardSection("原文书摘", card.highlight)
                    cardSection("适用场景", card.scenarios.map { "· \($0)" }.joined(separator: "\n"))
                    cardSection("引用金句", card.quote)
                    cardSection("延伸论点", card.extensions.map { "· \($0)" }.joined(separator: "\n"))
                    cardSection("反方视角", card.counter)
                    cardSection("案例提示", card.example)
                }
                .padding(24)
            } else {
                ContentUnavailableView(
                    "选择素材卡查看详情",
                    systemImage: "rectangle.stack",
                    description: Text("素材卡把单条书摘扩展成可引用到文章中的完整素材")
                )
                .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
    }

    private func cardSection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(content)
                .font(.system(size: 14))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(palette.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.borderSubtle, lineWidth: 0.5)
                )
        }
    }

    private func copyCard(_ card: WritingCard) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(renderMarkdown(card), forType: .string)
    }

    private func exportMarkdown(_ card: WritingCard) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "writing-card-\(card.id.uuidString.prefix(8)).md"
        if panel.runModal() == .OK, let url = panel.url {
            try? renderMarkdown(card).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func renderMarkdown(_ card: WritingCard) -> String {
        """
        # \(card.coreIdea)

        > \(card.quote)
        > ——《\(card.bookTitle ?? "未知书籍")》

        ## 原文书摘
        \(card.highlight)

        ## 适用场景
        \(card.scenarios.map { "- \($0)" }.joined(separator: "\n"))

        ## 延伸论点
        \(card.extensions.map { "- \($0)" }.joined(separator: "\n"))

        ## 反方视角
        \(card.counter)

        ## 案例提示
        \(card.example)
        """
    }
}
