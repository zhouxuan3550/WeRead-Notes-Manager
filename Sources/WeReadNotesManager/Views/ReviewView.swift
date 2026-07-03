import SwiftUI

struct ReviewView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @State private var currentIndex = 0
    @State private var showAnswer = false

    var body: some View {
        let notes = appVM.dueNotes

        VStack(spacing: 0) {
            header(count: notes.count)
            Divider()

            if notes.isEmpty {
                ContentUnavailableView(
                    "今天没有待复习笔记",
                    systemImage: "checkmark.seal",
                    description: Text("去书架里随便翻一本，也算温故。")
                )
            } else if let current = notes[safe: currentIndex] {
                VStack(spacing: 18) {
                    // 3D 翻转闪卡
                    FlipCardView(note: current, isFlipped: showAnswer)
                        .padding(.horizontal, 36)
                        .padding(.top, 28)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { showAnswer.toggle() }
                        }

                    if !showAnswer {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showAnswer = true }
                        } label: {
                            Label("显示想法", systemImage: "eye")
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                        }
                        .flatActionButton(.accent, height: 32)
                        .controlSize(.large)
                    } else {
                        // 4 档评级按钮 - 带粒子动画
                        HStack(spacing: 12) {
                            gradeButton(.again, notes: notes)
                            gradeButton(.hard, notes: notes)
                            gradeButton(.good, notes: notes)
                            gradeButton(.easy, notes: notes)
                        }
                        .controlSize(.large)
                    }

                    HStack(spacing: 20) {
                        Button {
                            move(-1, count: notes.count)
                            showAnswer = false
                        } label: {
                            Label("上一条", systemImage: "chevron.left")
                        }
                        .disabled(currentIndex == 0)

                        Button {
                            snooze(current)
                            advance(notes: notes)
                        } label: {
                            Label("稍后", systemImage: "clock")
                        }

                        Button {
                            move(1, count: notes.count)
                            showAnswer = false
                        } label: {
                            Label("下一条", systemImage: "chevron.right")
                        }
                        .disabled(currentIndex >= notes.count - 1)
                    }
                    .font(.system(size: 12))

                    Text("\(min(currentIndex + 1, notes.count)) / \(notes.count)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
    }

    private func gradeButton(_ grade: ReviewGrade, notes: [ReadingNote]) -> some View {
        GradeButton(grade: grade) {
            guard let note = notes[safe: currentIndex] else { return }
            appVM.review(note, grade: grade, context: modelContext)
            showAnswer = false
            advance(notes: notes)
        }
    }

    private func gradeColor(_ grade: ReviewGrade) -> Color {
        // 保留旧方法避免外部引用破坏，实际由 GradeButton 主题感知处理
        switch grade {
        case .again: return .red
        case .hard: return .orange
        case .good: return .green
        case .easy: return .blue
        }
    }

    private func previewInterval(_ grade: ReviewGrade) -> Int {
        guard let note = appVM.dueNotes[safe: currentIndex] else { return 0 }
        let current = SpacedRepetitionService.currentState(of: note)
        let next = SpacedRepetitionService.nextState(after: grade, current: current)
        return next.intervalDays
    }

    private func header(count: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("沉浸复习")
                    .font(.system(size: 20, weight: .semibold))
                Text("SRS 间隔重复 · 今天 due \(count) 条")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func move(_ delta: Int, count: Int) {
        currentIndex = min(max(currentIndex + delta, 0), max(count - 1, 0))
    }

    private func snooze(_ note: ReadingNote) {
        // 把 nextReviewAt 推迟到明天
        note.nextReviewAt = Date().addingTimeInterval(86400)
        note.updatedAt = Date()
    }

    private func advance(notes: [ReadingNote]) {
        if currentIndex >= notes.count - 1 {
            currentIndex = max(notes.count - 1, 0)
        }
    }
}

struct ReviewFocusCard: View {
    let note: ReadingNote
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        Button {
            appVM.selectedNote = note
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    if let book = note.book {
                        BookCoverView(book: book, size: .medium)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(book.title)
                                .font(.system(size: 15, weight: .semibold))
                            Text([book.author, note.chapter].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }

                Text(note.highlight)
                    .font(.system(size: 24, weight: .medium))
                    .lineSpacing(7)
                    .multilineTextAlignment(.leading)

                if let userNote = note.userNote, !userNote.isEmpty {
                    Divider()
                    Text(userNote)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .lineSpacing(5)
                }
            }
            .padding(28)
            .frame(maxWidth: 760, minHeight: 390, alignment: .topLeading)
            .glassPanel()
        }
        .buttonStyle(.plain)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
