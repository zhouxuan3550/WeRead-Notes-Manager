import SwiftUI

struct RandomNoteView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var currentNote: ReadingNote?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let note = currentNote {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let bookTitle = note.book?.title {
                            Text(bookTitle)
                                .font(.system(size: 18, weight: .bold))
                        }
                        if let author = note.book?.author {
                            Text(author)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        if let chapter = note.chapter {
                            Text(chapter)
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                        }

                        Text(note.highlight)
                            .font(.system(size: 16))
                            .lineSpacing(4)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.08))
                            )

                        if let userNote = note.userNote, !userNote.isEmpty {
                            Text(userNote)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }

                        HStack(spacing: 12) {
                            Button {
                                appVM.toggleFavorite(note)
                            } label: {
                                Label(note.isFavorite ? "已收藏" : "收藏",
                                      systemImage: note.isFavorite ? "star.fill" : "star")
                            }
                            .flatActionButton(height: 32)

                            Button {
                                appVM.markReviewed(note)
                            } label: {
                                Label("已复习", systemImage: "checkmark.circle")
                            }
                            .flatActionButton(height: 32)
                        }
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "暂无笔记",
                    systemImage: "shuffle",
                    description: Text("点击下方按钮随机抽取一条笔记")
                )
            }
        }
        .onAppear {
            if currentNote == nil {
                currentNote = appVM.randomNote()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("随机笔记")
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            Button {
                currentNote = appVM.randomNote()
            } label: {
                Label("换一条", systemImage: "shuffle")
            }
            .flatActionButton(.accent, height: 32)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
