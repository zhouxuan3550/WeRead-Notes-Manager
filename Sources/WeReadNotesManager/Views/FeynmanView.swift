import SwiftUI

// MARK: - 费曼学习视图
//
// 完整流程：
// 1. 配置（选择笔记/数量/风格）
// 2. AI 出题（loading）
// 3. 一题一答（带反馈）
// 4. 学习报告（分数 + 错题）

struct FeynmanView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themePalette) private var palette

    // 阶段：setup → generating → playing → finished
    @State private var phase: Phase = .setup
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var questionCount: Int = 3
    @State private var style: FeynmanStyle = .feynman

    @State private var session: FeynmanSession?
    @State private var currentAnswer: String = ""
    @State private var selectedOption: Int?
    @State private var showingFeedback: Bool = false
    @State private var evaluation: FeynmanEvaluation?
    @State private var isEvaluating: Bool = false
    @State private var errorMessage: String?

    @State private var mistakeStore = MistakeBookStore.shared

    enum Phase {
        case setup, generating, playing, finished
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            switch phase {
            case .setup:
                setupPhase
            case .generating:
                generatingPhase
            case .playing:
                playingPhase
            case .finished:
                finishedPhase
            }
        }
        .frame(width: 780, height: 600)
        .background(AmbientBackground(showGlows: true, showNoise: true))
    }

    // MARK: - 头部

    private var header: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text("费曼学习法")
                .font(.headline)
            Spacer()
            if phase == .playing, let session = session {
                Text("\(session.currentIndex + 1) / \(session.questions.count)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(palette.textTertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    // MARK: - 设置阶段

    private var setupPhase: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introCard

                Text("选择笔记")
                    .font(Typography.captionStrong)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(appVM.allNotes.filter { !$0.isDeleted }.prefix(20)) { note in
                            noteChip(note)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Divider().padding(.vertical, 8)

                Text("题目数量")
                    .font(Typography.captionStrong)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    ForEach([1, 3, 5, 10], id: \.self) { count in
                        Button {
                            questionCount = count
                        } label: {
                            Text("\(count) 题")
                                .font(Typography.bodyStrong)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(questionCount == count ? palette.accentSoft : palette.surface)
                                )
                                .foregroundStyle(questionCount == count ? palette.accent : palette.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)

                Text("风格")
                    .font(Typography.captionStrong)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    ForEach(FeynmanStyle.allCases) { s in
                        styleOption(s)
                    }
                }
                .padding(.horizontal, 4)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(palette.error)
                }

                Button {
                    startSession()
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("开始学习")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedNoteIDs.isEmpty)
                .padding(.top, 8)
            }
            .padding(16)
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(palette.accentSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(palette.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("费曼学习法")
                        .font(Typography.title3)
                        .foregroundStyle(palette.textPrimary)
                    Text("教是最好的学")
                        .font(Typography.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            Text("AI 根据你的笔记生成测试题。答错会自动加入错题本，下次复习时会优先推送。")
                .font(Typography.caption)
                .foregroundStyle(palette.textSecondary)
                .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.accent.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func noteChip(_ note: ReadingNote) -> some View {
        let isSelected = selectedNoteIDs.contains(note.id)
        return Button {
            if isSelected {
                selectedNoteIDs.remove(note.id)
            } else {
                selectedNoteIDs.insert(note.id)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text((note.book?.title ?? "未知").prefix(20))
                    .font(Typography.captionStrong)
                    .foregroundStyle(isSelected ? palette.accent : palette.textPrimary)
                    .lineLimit(1)
                Text(note.highlight.prefix(40))
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 200, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? palette.accentSoft : palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? palette.accent : palette.borderSubtle, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func styleOption(_ s: FeynmanStyle) -> some View {
        let isSelected = style == s
        return Button {
            style = s
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? palette.accent : palette.textTertiary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(s.rawValue)
                        .font(Typography.bodyStrong)
                        .foregroundStyle(palette.textPrimary)
                    Text(s.description)
                        .font(Typography.caption)
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? palette.accentSoft.opacity(0.4) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? palette.accent.opacity(0.3) : .clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 生成中

    private var generatingPhase: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .scaleEffect(1.5)
            Text("AI 正在出题...")
                .font(Typography.title3)
                .foregroundStyle(palette.textPrimary)
            Text("基于你选择的笔记生成 \(questionCount) 道测试题")
                .font(Typography.caption)
                .foregroundStyle(palette.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 答题阶段

    private var playingPhase: some View {
        Group {
            if let session = session, session.currentIndex < session.questions.count {
                let question = session.questions[session.currentIndex]
                VStack(spacing: 0) {
                    progressBar(session: session)
                    ScrollView {
                        questionCard(question: question)
                            .padding(24)
                    }
                    bottomBar(question: question, session: session)
                }
            } else {
                Text("题目加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func progressBar(session: FeynmanSession) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(palette.surface)

                Rectangle()
                    .fill(palette.accent)
                    .frame(width: geo.size.width * Double(session.currentIndex + 1) / Double(session.questions.count))
                    .animation(.easeOut(duration: 0.4), value: session.currentIndex)
            }
        }
        .frame(height: 3)
    }

    private func questionCard(question: FeynmanQuestion) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // 头部
            HStack(spacing: 8) {
                Image(systemName: question.type.systemImage)
                    .foregroundStyle(palette.accent)
                Text(question.type.rawValue)
                    .font(Typography.captionStrong)
                    .foregroundStyle(palette.accent)
                Text("·")
                    .foregroundStyle(palette.textTertiary)
                Text(question.difficulty.rawValue)
                    .font(Typography.caption)
                    .foregroundStyle(palette.textTertiary)

                Spacer()

                if mistakeStore.contains(question) {
                    Label("错题", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.warning)
                }
            }

            // 上下文引用
            if let context = question.context, !context.isEmpty {
                Text("「\(context.prefix(80))…」")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textTertiary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(palette.surface.opacity(0.5))
                    )
            }

            // 题干
            Text(question.prompt)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 答题区
            answerArea(for: question)

            // 反馈
            if showingFeedback {
                feedbackCard(for: question)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }

    @ViewBuilder
    private func answerArea(for question: FeynmanQuestion) -> some View {
        switch question.type {
        case .multipleChoice:
            if let options = question.options {
                VStack(spacing: 8) {
                    ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                        Button {
                            if !showingFeedback {
                                selectedOption = idx
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedOption == idx ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selectedOption == idx ? palette.accent : palette.textTertiary)

                                Text(option)
                                    .font(Typography.body)
                                    .foregroundStyle(palette.textPrimary)

                                Spacer()

                                if showingFeedback {
                                    if idx == question.correctIndex {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(palette.success)
                                    } else if selectedOption == idx {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(palette.error)
                                    }
                                }
                            }
                            .padding(12)
                            .background(optionBackground(idx: idx, question: question))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(optionBorder(idx: idx, question: question), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(showingFeedback)
                    }
                }
            }

        case .trueFalse:
            HStack(spacing: 12) {
                trueFalseButton(text: "✓ 正确", isTrue: true, question: question)
                trueFalseButton(text: "✗ 错误", isTrue: false, question: question)
            }

        case .fillBlank, .shortAnswer:
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $currentAnswer)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .padding(10)
                    .frame(minHeight: 80, maxHeight: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(palette.surface.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(palette.borderMedium, lineWidth: 0.5)
                    )
                    .disabled(showingFeedback)
            }

        case .association:
            VStack(alignment: .leading, spacing: 8) {
                Text("思考这个观点与你其他笔记的关联，1-3 句话：")
                    .font(Typography.caption)
                    .foregroundStyle(palette.textSecondary)
                TextEditor(text: $currentAnswer)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .padding(10)
                    .frame(minHeight: 80, maxHeight: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(palette.surface.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(palette.borderMedium, lineWidth: 0.5)
                    )
                    .disabled(showingFeedback)
            }
        }
    }

    private func trueFalseButton(text: String, isTrue: Bool, question: FeynmanQuestion) -> some View {
        Button {
            if !showingFeedback {
                currentAnswer = isTrue ? "true" : "false"
            }
        } label: {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tfBackground(isTrue: isTrue, question: question))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(tfBorder(isTrue: isTrue, question: question), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(showingFeedback)
    }

    private func tfBackground(isTrue: Bool, question: FeynmanQuestion) -> Color {
        if !showingFeedback { return palette.surface.opacity(0.5) }
        let userChose = (currentAnswer == "true") == isTrue
        if userChose {
            return question.correctText?.lowercased() == currentAnswer.lowercased()
                ? palette.success.opacity(0.2) : palette.error.opacity(0.2)
        }
        return question.correctText?.lowercased() == (isTrue ? "true" : "false")
            ? palette.success.opacity(0.2) : palette.surface.opacity(0.5)
    }

    private func tfBorder(isTrue: Bool, question: FeynmanQuestion) -> Color {
        if !showingFeedback { return palette.borderSubtle }
        let correctAnswer = question.correctText?.lowercased() == "true"
        return correctAnswer == isTrue ? palette.success : palette.borderSubtle
    }

    private func optionBackground(idx: Int, question: FeynmanQuestion) -> Color {
        if !showingFeedback {
            return selectedOption == idx ? palette.accentSoft : palette.surface.opacity(0.5)
        }
        if idx == question.correctIndex { return palette.success.opacity(0.2) }
        if selectedOption == idx { return palette.error.opacity(0.2) }
        return palette.surface.opacity(0.3)
    }

    private func optionBorder(idx: Int, question: FeynmanQuestion) -> Color {
        if !showingFeedback {
            return selectedOption == idx ? palette.accent : palette.borderSubtle
        }
        if idx == question.correctIndex { return palette.success }
        if selectedOption == idx { return palette.error }
        return palette.borderSubtle
    }

    // MARK: - 反馈卡

    private func feedbackCard(for question: FeynmanQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: isAnswerCorrect(question) ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isAnswerCorrect(question) ? palette.success : palette.error)
                Text(isAnswerCorrect(question) ? "回答正确！" : "答案有偏差")
                    .font(Typography.title3)
                    .foregroundStyle(isAnswerCorrect(question) ? palette.success : palette.error)

                Spacer()

                if let eval = evaluation {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < eval.score / 2 ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.warning)
                        }
                    }
                }
            }

            if let correctText = question.correctText {
                Text("标准答案：\(correctText)")
                    .font(Typography.bodyStrong)
                    .foregroundStyle(palette.textPrimary)
            }

            if let eval = evaluation {
                Text(eval.feedback)
                    .font(Typography.body)
                    .foregroundStyle(palette.textSecondary)
                    .lineSpacing(3)
            } else {
                Text(question.explanation)
                    .font(Typography.body)
                    .foregroundStyle(palette.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((isAnswerCorrect(question) ? palette.success : palette.error).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((isAnswerCorrect(question) ? palette.success : palette.error).opacity(0.3), lineWidth: 1)
        )
    }

    private func isAnswerCorrect(_ question: FeynmanQuestion) -> Bool {
        question.isCorrect == true
    }

    // MARK: - 底部按钮

    private func bottomBar(question: FeynmanQuestion, session: FeynmanSession) -> some View {
        HStack(spacing: 10) {
            if !showingFeedback {
                Button("跳过") {
                    self.session?.questions[self.session?.currentIndex ?? 0].userAnswer = "(skipped)"
                    self.session?.questions[self.session?.currentIndex ?? 0].isCorrect = false
                    advanceOrFinish()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("提交答案") {
                    submit(question: question, session: session)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasAnswer(question: question))
            } else {
                Spacer()
                Button(session.currentIndex == session.questions.count - 1 ? "完成" : "下一题") {
                    advanceOrFinish()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(palette.surface.opacity(0.5))
    }

    private func hasAnswer(question: FeynmanQuestion) -> Bool {
        switch question.type {
        case .multipleChoice: return selectedOption != nil
        case .trueFalse: return !currentAnswer.isEmpty
        case .fillBlank, .shortAnswer, .association:
            return !currentAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func submit(question: FeynmanQuestion, session: FeynmanSession) {
        // 记录答案
        var q = question
        switch q.type {
        case .multipleChoice:
            q.userAnswer = q.options?[safe: selectedOption ?? 0] ?? ""
            q.isCorrect = (selectedOption == q.correctIndex)
        case .trueFalse:
            q.userAnswer = currentAnswer
            q.isCorrect = (currentAnswer.lowercased() == q.correctText?.lowercased())
        case .fillBlank, .shortAnswer, .association:
            q.userAnswer = currentAnswer
            // 客观题用 AI 评估
            evaluate(question: q, session: session)
            return
        }
        self.session?.questions[self.session?.currentIndex ?? 0] = q

        // 答错入错题本
        if q.isCorrect == false {
            mistakeStore.recordMistake(question: q, userAnswer: q.userAnswer)
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingFeedback = true
        }
    }

    private func evaluate(question: FeynmanQuestion, session: FeynmanSession) {
        isEvaluating = true
        Task {
            do {
                let eval = try await FeynmanService.evaluateAnswer(question: question, userAnswer: currentAnswer)
                await MainActor.run {
                    var q = question
                    q.userAnswer = currentAnswer
                    q.isCorrect = eval.isCorrect
                    self.session?.questions[self.session?.currentIndex ?? 0] = q
                    self.evaluation = eval

                    if !eval.isCorrect {
                        mistakeStore.recordMistake(question: q, userAnswer: currentAnswer)
                    }

                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingFeedback = true
                        isEvaluating = false
                    }
                }
            } catch {
                await MainActor.run {
                    var q = question
                    q.userAnswer = currentAnswer
                    q.isCorrect = false
                    self.session?.questions[self.session?.currentIndex ?? 0] = q
                    mistakeStore.recordMistake(question: q, userAnswer: currentAnswer)
                    withAnimation {
                        showingFeedback = true
                        isEvaluating = false
                    }
                }
            }
        }
    }

    private func advanceOrFinish(session: FeynmanSession) {
        advanceOrFinish()
    }

    private func advanceOrFinish() {
        withAnimation {
            showingFeedback = false
            evaluation = nil
            selectedOption = nil
            currentAnswer = ""
            session?.currentIndex += 1
        }

        if let currentSession = session,
           currentSession.currentIndex >= currentSession.questions.count {
            session?.endDate = Date()
            withAnimation {
                phase = .finished
            }
        }
    }

    // MARK: - 完成阶段

    private var finishedPhase: some View {
        Group {
            if let session = session {
                ScrollView {
                    VStack(spacing: 18) {
                        scoreCircle(session: session)
                        statsGrid(session: session)
                        if !session.incorrectQuestions.isEmpty {
                            incorrectSection(session: session)
                        }
                        HStack(spacing: 10) {
                            Button {
                                phase = .setup
                                self.session?.currentIndex = 0
                                selectedNoteIDs.removeAll()
                            } label: {
                                Label("再来一组", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                dismiss()
                            } label: {
                                Label("完成", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(24)
                }
            }
        }
    }

    private func scoreCircle(session: FeynmanSession) -> some View {
        let percent = session.score
        return ZStack {
            Circle()
                .stroke(palette.borderSubtle, lineWidth: 8)
                .frame(width: 140, height: 140)

            Circle()
                .trim(from: 0, to: percent)
                .stroke(
                    scoreColor(percent: percent),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 140, height: 140)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percent)

            VStack(spacing: 2) {
                Text("\(Int(percent * 100))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(scoreColor(percent: percent))
                Text("\(session.correctCount)/\(session.questions.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
            }
        }
    }

    private func scoreColor(percent: Double) -> Color {
        switch percent {
        case 0.8...: return palette.success
        case 0.5..<0.8: return palette.warning
        default: return palette.error
        }
    }

    private func statsGrid(session: FeynmanSession) -> some View {
        let elapsed = Date().timeIntervalSince(session.startDate)
        let minutes = Int(elapsed / 60)
        return HStack(spacing: 10) {
            statCard("正确", "\(session.correctCount)", palette.success)
            statCard("错误", "\(session.incorrectQuestions.count)", palette.error)
            statCard("用时", "\(minutes) 分", palette.accent)
        }
    }

    private func statCard(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(Typography.micro)
                .tracking(0.6)
                .foregroundStyle(palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.surface.opacity(0.5))
        )
    }

    private func incorrectSection(session: FeynmanSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(palette.warning)
                Text("错题回顾 (\(session.incorrectQuestions.count))")
                    .font(Typography.title3)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("已加入错题本，下次复习时优先推送")
                    .font(Typography.caption)
                    .foregroundStyle(palette.textTertiary)
            }

            ForEach(session.incorrectQuestions) { q in
                VStack(alignment: .leading, spacing: 4) {
                    Text(q.prompt)
                        .font(Typography.bodyStrong)
                        .foregroundStyle(palette.textPrimary)
                    Text("你的答案：\(q.userAnswer ?? "(空)")")
                        .font(Typography.caption)
                        .foregroundStyle(palette.error)
                    Text("正确答案：\(q.correctText ?? "")")
                        .font(Typography.caption)
                        .foregroundStyle(palette.success)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(palette.surface.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.borderSubtle, lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - 启动

    private func startSession() {
        guard !selectedNoteIDs.isEmpty else { return }
        phase = .generating
        errorMessage = nil

        let selectedNotes = appVM.allNotes.filter { selectedNoteIDs.contains($0.id) }

        Task {
            do {
                let questions = try await FeynmanService.generateQuestions(
                    for: selectedNotes,
                    count: questionCount,
                    style: style
                )
                await MainActor.run {
                    if questions.isEmpty {
                        self.errorMessage = "AI 未能生成题目，请重试"
                        self.phase = .setup
                    } else {
                        self.session = FeynmanSession(
                            noteIDs: Array(selectedNoteIDs),
                            questions: questions,
                            style: style
                        )
                        withAnimation {
                            self.phase = .playing
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.phase = .setup
                }
            }
        }
    }
}

// MARK: - 安全索引扩展

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
