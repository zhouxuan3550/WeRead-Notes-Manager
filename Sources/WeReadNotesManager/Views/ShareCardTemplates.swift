import SwiftUI

// MARK: - 数据

struct ShareCardData {
    let highlight: String
    let bookTitle: String
    let author: String?
    let userNote: String?
    let themeColor: Color
}

// MARK: - 协议

protocol ShareCardTemplate {
    var id: String { get }
    var name: String { get }
    func body(for card: ShareCardData) -> AnyView
}

// MARK: - 内置模板

enum BuiltInShareCardTemplates {
    static let all: [ShareCardTemplate] = [
        MinimalTemplate(),
        PaperTemplate(),
        DarkTemplate(),
        GradientTemplate(),
        SocialTemplate()
    ]

    static func template(id: String) -> ShareCardTemplate {
        all.first { $0.id == id } ?? MinimalTemplate()
    }
}

private struct MinimalTemplate: ShareCardTemplate {
    let id = "minimal"
    let name = "极简"

    func body(for card: ShareCardData) -> AnyView {
        AnyView(
            ZStack(alignment: .leading) {
                Color.white
                VStack(alignment: .leading, spacing: 20) {
                    Text("“")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(card.themeColor.opacity(0.4))
                    Text(card.highlight)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.black)
                        .lineSpacing(6)
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("《\(card.bookTitle)》")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                            if let author = card.author {
                                Text(author)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
                .padding(36)
            }
            .frame(width: 700, height: 420)
        )
    }
}

private struct PaperTemplate: ShareCardTemplate {
    let id = "paper"
    let name = "纸张"

    func body(for card: ShareCardData) -> AnyView {
        AnyView(
            ZStack(alignment: .leading) {
                Color(red: 0.97, green: 0.95, blue: 0.91)
                VStack(alignment: .leading, spacing: 18) {
                    Text(card.highlight)
                        .font(.system(size: 24, weight: .medium, design: .serif))
                        .foregroundStyle(Color(red: 0.2, green: 0.15, blue: 0.1))
                        .lineSpacing(8)
                    if let userNote = card.userNote, !userNote.isEmpty {
                        Text(userNote)
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(Color(red: 0.4, green: 0.35, blue: 0.3))
                            .lineSpacing(5)
                            .padding(.top, 8)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("—— 《\(card.bookTitle)》\(card.author.map { " · \($0)" } ?? "")")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Color(red: 0.35, green: 0.3, blue: 0.25))
                    }
                }
                .padding(40)
            }
            .frame(width: 700, height: 420)
        )
    }
}

private struct DarkTemplate: ShareCardTemplate {
    let id = "dark"
    let name = "深色"

    func body(for card: ShareCardData) -> AnyView {
        AnyView(
            ZStack(alignment: .leading) {
                Color(red: 0.08, green: 0.08, blue: 0.1)
                VStack(alignment: .leading, spacing: 20) {
                    Text(card.highlight)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineSpacing(7)
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Rectangle()
                                .fill(card.themeColor)
                                .frame(width: 40, height: 3)
                            Text("《\(card.bookTitle)》")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            if let author = card.author {
                                Text(author)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.gray)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(40)
            }
            .frame(width: 700, height: 420)
        )
    }
}

private struct GradientTemplate: ShareCardTemplate {
    let id = "gradient"
    let name = "渐变"

    func body(for card: ShareCardData) -> AnyView {
        AnyView(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [card.themeColor.opacity(0.8), card.themeColor.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .leading, spacing: 20) {
                    Text(card.highlight)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white)
                        .lineSpacing(7)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    Spacer()
                    HStack {
                        Spacer()
                        Text("《\(card.bookTitle)》")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(40)
            }
            .frame(width: 700, height: 420)
        )
    }
}

private struct SocialTemplate: ShareCardTemplate {
    let id = "social"
    let name = "小红书"

    func body(for card: ShareCardData) -> AnyView {
        AnyView(
            ZStack {
                Color(red: 0.99, green: 0.96, blue: 0.94)
                VStack(spacing: 0) {
                    HStack {
                        Text("今日书摘")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(card.themeColor)
                        Spacer()
                    }
                    .padding(.bottom, 16)

                    Text(card.highlight)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(red: 0.2, green: 0.1, blue: 0.1))
                        .lineSpacing(8)

                    Spacer()

                    HStack(spacing: 8) {
                        Circle()
                            .fill(card.themeColor)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "book.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("《\(card.bookTitle)》")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.2, green: 0.1, blue: 0.1))
                            if let author = card.author {
                                Text(author)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(36)
            }
            .frame(width: 700, height: 420)
        )
    }
}
