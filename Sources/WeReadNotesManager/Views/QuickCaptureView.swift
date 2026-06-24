import SwiftUI
import SwiftData

/// 菜单栏 Quick Capture 弹窗。
/// 用户在菜单栏图标点击或按 ⌥Space 唤起，快速记一条笔记到指定书。
struct QuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @State private var highlight: String = ""
    @State private var userNote: String = ""
    @State private var chapter: String = ""
    @State private var selectedBookID: UUID?
    @State private var newBookTitle: String = ""
    @State private var showNewBookField: Bool = false
    @State private var savedFeedback: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("快速记录")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    saveAndDismiss()
                } label: {
                    Text("保存 (⌘↩)")
                        .font(.system(size: 12))
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!canSave)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                // 书籍选择
                HStack(spacing: 8) {
                    if showNewBookField {
                        TextField("新书名", text: $newBookTitle)
                            .textFieldStyle(.roundedBorder)
                        Button("选择已有") {
                            showNewBookField = false
                            newBookTitle = ""
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                    } else {
                        Picker("书", selection: $selectedBookID) {
                            Text("选择书籍...").tag(UUID?.none)
                            ForEach(books.prefix(20)) { book in
                                Text(book.title).tag(Optional(book.id))
                            }
                            Divider()
                            Button("新建书...") {
                                showNewBookField = true
                            }
                            .tag(UUID?.none)
                        }
                        .labelsHidden()
                    }
                }

                if !showNewBookField {
                    HStack(spacing: 6) {
                        TextField("章节（可选）", text: $chapter)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("划线 / 内容")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $highlight)
                        .font(.system(size: 13))
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("我的想法（可选）")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $userNote)
                        .font(.system(size: 12))
                        .frame(minHeight: 40)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                }

                if let savedFeedback {
                    Text(savedFeedback)
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                }
            }
            .padding(14)
        }
        .frame(width: 440, height: 360)
    }

    private var canSave: Bool {
        let textOK = !highlight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let bookOK = selectedBookID != nil || !newBookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return textOK && bookOK
    }

    private func saveAndDismiss() {
        // 1. 确定书
        let book: Book?
        if showNewBookField {
            let title = newBookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            let new = Book(title: title, author: nil)
            modelContext.insert(new)
            book = new
        } else {
            guard let id = selectedBookID else { return }
            book = books.first { $0.id == id }
        }

        guard let targetBook = book else { return }

        // 2. 创建笔记
        let highlightText = highlight.trimmingCharacters(in: .whitespacesAndNewlines)
        let userText = userNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let chapterText = chapter.trimmingCharacters(in: .whitespacesAndNewlines)

        let note = ReadingNote(
            book: targetBook,
            chapter: chapterText.isEmpty ? nil : chapterText,
            highlight: highlightText,
            userNote: userText.isEmpty ? nil : userText,
            location: nil,
            source: "quick_capture",
            sourceHash: "qc-\(UUID().uuidString)"
        )
        targetBook.notes.append(note)
        targetBook.updatedAt = Date()

        SafePersistence.save(modelContext, label: "quickCapture")

        savedFeedback = "已保存到 《\(targetBook.title)》"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            dismiss()
        }
    }
}