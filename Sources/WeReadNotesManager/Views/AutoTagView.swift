import SwiftUI
import SwiftData

/// AI 自动标签视图：选择范围 → 生成候选 → 用户确认后写入 Tag。
struct AutoTagView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themePalette) private var palette

    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]

    @State private var scope: Scope = .all
    @State private var selectedBook: Book?
    @State private var proposals: [NoteTagProposal] = []
    @State private var selectedProposals: Set<String> = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    enum Scope: String, CaseIterable, Identifiable {
        case all = "全部笔记"
        case book = "单本书"
        case favorites = "收藏笔记"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 560, minHeight: 480)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI 推荐标签")
                    .font(.system(size: 18, weight: .semibold))
                Text("基于笔记内容生成主题标签，确认后自动关联")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var content: some View {
        VStack(spacing: 16) {
            configPanel

            if proposals.isEmpty && !isGenerating {
                Spacer()
                ContentUnavailableView(
                    "准备生成标签",
                    systemImage: "tag",
                    description: Text("选择范围后点击生成")
                )
                Spacer()
            } else if isGenerating {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在分析笔记主题...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                proposalsPanel
            }
        }
        .padding(20)
    }

    private var configPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Picker("范围", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                if scope == .book {
                    Picker("书籍", selection: $selectedBook) {
                        Text("请选择").tag(Book?.none)
                        ForEach(books) { book in
                            Text(book.title).tag(book as Book?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }

                Spacer()

                Button {
                    Task { await generate() }
                } label: {
                    Label("生成标签", systemImage: "sparkles")
                }
                .flatActionButton(.accent, height: 32)
                .disabled(isGenerating || !canGenerate)
            }

            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(10)
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
            }
        }
    }

    private var proposalsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("候选标签（\(proposals.count)）")
                .font(.system(size: 14, weight: .semibold))

            ScrollView {
                FlowLayout(spacing: 10) {
                    ForEach(proposals, id: \.name) { proposal in
                        let isSelected = selectedProposals.contains(proposal.name)
                        Button {
                            toggle(proposal.name)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 12))
                                Text(proposal.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text("\(Int(proposal.confidence * 100))%")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text("· \(proposal.noteIndices.count) 条")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(isSelected ? palette.accent.opacity(0.18) : palette.surfaceElevated)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? palette.accent : palette.borderSubtle, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Text("已选择 \(selectedProposals.count) 个")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("全选") {
                    selectedProposals = Set(proposals.map { $0.name })
                }
                .flatActionButton(height: 28)
                .controlSize(.small)

                Button("清空") {
                    selectedProposals.removeAll()
                }
                .flatActionButton(height: 28)
                .controlSize(.small)

                Button {
                    applySelectedTags()
                } label: {
                    Label("应用标签", systemImage: "checkmark")
                }
                .flatActionButton(.accent, height: 32)
                .disabled(selectedProposals.isEmpty)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canGenerate: Bool {
        switch scope {
        case .all, .favorites:
            return true
        case .book:
            return selectedBook != nil
        }
    }

    private var targetNotes: [ReadingNote] {
        let notes: [ReadingNote]
        switch scope {
        case .all:
            notes = appVM.allNotes
        case .book:
            notes = selectedBook?.notes ?? []
        case .favorites:
            notes = appVM.allNotes.filter { $0.isFavorite }
        }
        return notes.filter { !$0.isDeleted }
    }

    private func toggle(_ name: String) {
        if selectedProposals.contains(name) {
            selectedProposals.remove(name)
        } else {
            selectedProposals.insert(name)
        }
    }

    private var targetInputs: [AutoTagNoteInput] {
        targetNotes.map { note in
            AutoTagNoteInput(
                highlight: note.highlight,
                userNote: note.userNote,
                bookTitle: note.book?.title,
                chapter: note.chapter
            )
        }
    }

    private func generate() async {
        guard let apiKey = currentAPIKey, !apiKey.isEmpty else {
            errorMessage = "请先在设置中配置 AI API Key"
            return
        }
        guard !targetInputs.isEmpty else {
            errorMessage = "所选范围内没有笔记"
            return
        }

        isGenerating = true
        errorMessage = nil
        proposals = []
        selectedProposals.removeAll()

        let runner = makeRunner(apiKey: apiKey)
        do {
            proposals = try await runner.run(AutoTagTask(), input: targetInputs)
            selectedProposals = Set(proposals.filter { $0.confidence >= 0.7 }.map { $0.name })
            isGenerating = false
        } catch {
            errorMessage = error.localizedDescription
            isGenerating = false
        }
    }

    private func applySelectedTags() {
        guard !selectedProposals.isEmpty else { return }

        let selected = proposals.filter { selectedProposals.contains($0.name) }
        for proposal in selected {
            guard let tag = appVM.findOrCreateTag(name: proposal.name, context: modelContext) else { continue }
            for index in proposal.noteIndices {
                guard index >= 0, index < targetNotes.count else { continue }
                let note = targetNotes[index]
                appVM.addTag(tag, to: note, context: modelContext)
            }
        }

        SafePersistence.save(modelContext, label: "applyAITags")
        statusMessage = "已应用 \(selectedProposals.count) 个标签到 \(Set(selected.flatMap { $0.noteIndices }).count) 条笔记"
        selectedProposals.removeAll()
    }

    private var currentAPIKey: String? {
        let provider = AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "") ?? .openAI
        return KeychainService.loadAPIKey(for: provider)
    }

    private var currentModel: String {
        let provider = AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "") ?? .openAI
        switch provider {
        case .openAI: return UserDefaults.standard.string(forKey: "openAIModel") ?? provider.defaultModel
        case .deepSeek: return UserDefaults.standard.string(forKey: "deepSeekModel") ?? provider.defaultModel
        case .glm: return UserDefaults.standard.string(forKey: "glmModel") ?? provider.defaultModel
        case .minimax, .aliyun, .doubao: return provider.savedModel
        }
    }

    private func makeRunner(apiKey: String) -> AITaskRunner {
        let provider = AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "") ?? .openAI
        let service = AIChatService(provider: provider, apiKey: apiKey, model: currentModel)
        let cache = AIResultCache(context: modelContext)
        let quota = AIQuotaTracker()
        return AITaskRunner(service: service, cache: cache, quota: quota)
    }
}
