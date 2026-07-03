import SwiftUI
import SwiftData

/// 回收站：显示最近 30 天内被软删除的笔记，可恢复或永久删除。
struct TrashView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<ReadingNote> { $0.isDeleted },
           sort: \ReadingNote.deletedAt, order: .reverse)
    private var trashedNotes: [ReadingNote]
    @State private var showEmptyAllConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if trashedNotes.isEmpty {
                ContentUnavailableView(
                    "回收站是空的",
                    systemImage: "trash",
                    description: Text("删除的笔记会在此处保留 30 天，之后自动清理。")
                )
            } else {
                List {
                    Section {
                        ForEach(trashedNotes) { note in
                            TrashRow(note: note)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        appVM.purgeNote(note, context: modelContext)
                                    } label: {
                                        Label("永久删除", systemImage: "trash.fill")
                                    }
                                    Button {
                                        appVM.restoreNote(note, context: modelContext)
                                    } label: {
                                        Label("恢复", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.blue)
                                }
                        }
                    } header: {
                        Text("\(trashedNotes.count) 条待清理")
                    } footer: {
                        Text("超过 30 天的笔记会被自动清理。")
                            .font(.system(size: 11))
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("回收站")
                    .font(.system(size: 20, weight: .semibold))
                Text("误删的笔记可以在这里恢复。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !trashedNotes.isEmpty {
                Button("清空回收站", role: .destructive) {
                    showEmptyAllConfirm = true
                }
                .flatActionButton(height: 32)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .confirmationDialog("确认清空回收站？", isPresented: $showEmptyAllConfirm, titleVisibility: .visible) {
            Button("永久删除 \(trashedNotes.count) 条", role: .destructive) {
                emptyAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销。")
        }
    }

    private func emptyAll() {
        for note in trashedNotes {
            appVM.purgeNote(note, context: modelContext)
        }
    }
}

private struct TrashRow: View {
    let note: ReadingNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let bookTitle = note.book?.title {
                    Text(bookTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let deletedAt = note.deletedAt {
                    Text(deletedAt.shortString)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            Text(note.highlight)
                .font(.system(size: 13))
                .lineLimit(2)
                .foregroundStyle(.primary)
            if let userNote = note.userNote, !userNote.isEmpty {
                Text(userNote)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}