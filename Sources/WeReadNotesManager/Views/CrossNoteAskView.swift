import SwiftUI
import SwiftData

/// AI 助手视图 - 提供实用的笔记处理功能
struct CrossNoteAskView: View {
    @Environment(AppViewModel.self) private var appVM
    @Query private var allBooks: [Book]
    
    // AI 配置
    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.openAI.rawValue
    @AppStorage("openAIModel") private var openAIModel = AIProvider.openAI.defaultModel
    @AppStorage("deepSeekModel") private var deepSeekModel = AIProvider.deepSeek.defaultModel
    @AppStorage("glmModel") private var glmModel = AIProvider.glm.defaultModel
    
    // 状态
    @State private var selectedBook: Book?
    @State private var selectedNotes: Set<ReadingNote> = []
    @State private var isProcessing = false
    @State private var resultText = ""
    @State private var errorMessage: String?
    
    // 快捷功能
    enum QuickAction {
        case summarize
        case extractKeyPoints
        case generateTags
        case translate
        case rewrite
        case createFlashcards
    }
    
    @State private var currentAction: QuickAction?
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            HStack(spacing: 0) {
                // 左侧：选择笔记
                noteSelectionPanel
                    .frame(width: 320)
                
                Divider()
                
                // 右侧：AI 处理
                aiProcessingPanel
            }
        }
    }
    
    // MARK: - 头部
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI 助手")
                    .font(.system(size: 20, weight: .semibold))
                Text("选择笔记，让 AI 帮你处理")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("处理中...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - 笔记选择面板
    
    private var noteSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 书籍选择
            VStack(alignment: .leading, spacing: 8) {
                Text("选择书籍")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                Picker("", selection: Binding(
                    get: { selectedBook },
                    set: { selectedBook = $0; selectedNotes.removeAll() }
                )) {
                    Text("全部书籍").tag(Book?.none)
                    if !allBooks.isEmpty {
                        Divider()
                        ForEach(allBooks) { book in
                            Text(book.title).tag(book as Book?)
                        }
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
            }
            
            Divider().padding(.vertical, 8)
            
            // 笔记列表
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("选择笔记 (\(selectedNotes.count))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !selectedNotes.isEmpty {
                        Button("清空") {
                            selectedNotes.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
                .padding(.horizontal, 16)
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(availableNotes) { note in
                            NoteSelectionRow(
                                note: note,
                                isSelected: selectedNotes.contains(note)
                            ) {
                                if selectedNotes.contains(note) {
                                    selectedNotes.remove(note)
                                } else {
                                    selectedNotes.insert(note)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            
            Divider().padding(.vertical, 8)
            
            // 快捷选择
            VStack(alignment: .leading, spacing: 8) {
                Text("快捷选择")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Button("全部") {
                        selectedNotes = Set(availableNotes)
                    }
                    Button("收藏") {
                        selectedNotes = Set(availableNotes.filter { $0.isFavorite })
                    }
                    Button("未复习") {
                        selectedNotes = Set(availableNotes.filter { !$0.isReviewed })
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(DesignSystem.Colors.surface.opacity(0.3))
    }
    
    // MARK: - AI 处理面板
    
    private var aiProcessingPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 快捷操作
            VStack(alignment: .leading, spacing: 12) {
                Text("快捷功能")
                    .font(.system(size: 13, weight: .semibold))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    QuickActionButton(
                        title: "总结笔记",
                        subtitle: "提炼核心内容",
                        icon: "doc.text.magnifyingglass"
                    ) {
                        performAction(.summarize)
                    }
                    
                    QuickActionButton(
                        title: "提取要点",
                        subtitle: "关键信息",
                        icon: "list.bullet"
                    ) {
                        performAction(.extractKeyPoints)
                    }
                    
                    QuickActionButton(
                        title: "生成标签",
                        subtitle: "AI 推荐标签",
                        icon: "tag"
                    ) {
                        performAction(.generateTags)
                    }
                    
                    QuickActionButton(
                        title: "翻译内容",
                        subtitle: "中英文互译",
                        icon: "globe"
                    ) {
                        performAction(.translate)
                    }
                    
                    QuickActionButton(
                        title: "润色改写",
                        subtitle: "优化表达",
                        icon: "wand.and.stars"
                    ) {
                        performAction(.rewrite)
                    }
                    
                    QuickActionButton(
                        title: "制作闪卡",
                        subtitle: "Anki 格式",
                        icon: "rectangle.on.rectangle"
                    ) {
                        performAction(.createFlashcards)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            
            Divider()
            
            // 结果区域
            VStack(alignment: .leading, spacing: 12) {
                Text("结果")
                    .font(.system(size: 13, weight: .semibold))
                
                if let errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                ScrollView {
                    if resultText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)
                            Text("选择笔记后使用快捷功能")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        Text(resultText)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
                .background(DesignSystem.Colors.surface.opacity(0.5))
                .cornerRadius(10)
                
                if !resultText.isEmpty {
                    HStack(spacing: 8) {
                        Spacer()
                        Button("复制") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(resultText, forType: .string)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("清空") {
                            resultText = ""
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - 辅助方法
    
    private var availableNotes: [ReadingNote] {
        if let book = selectedBook {
            return book.notes.filter { !$0.isDeleted }
        } else {
            return appVM.allNotes
        }
    }
    
    private var cleanedAPIKey: String {
        KeychainService.loadAPIKey(for: currentProvider) ?? ""
    }
    
    private var currentProvider: AIProvider {
        AIProvider(rawValue: aiProviderRaw) ?? .openAI
    }
    
    private var currentModel: String {
        switch currentProvider {
        case .openAI: return openAIModel
        case .deepSeek: return deepSeekModel
        case .glm: return glmModel
        }
    }
    
    private func performAction(_ action: QuickAction) {
        guard !selectedNotes.isEmpty else {
            errorMessage = "请先选择笔记"
            return
        }
        
        guard !cleanedAPIKey.isEmpty else {
            errorMessage = "请先在设置中配置 AI API Key"
            return
        }
        
        isProcessing = true
        currentAction = action
        errorMessage = nil
        resultText = ""
        
        let notesText = selectedNotes.map { note in
            var text = note.highlight
            if let userNote = note.userNote, !userNote.isEmpty {
                text += "\n\n我的想法：\(userNote)"
            }
            return text
        }.joined(separator: "\n\n---\n\n")
        
        let prompt = buildPrompt(for: action, notes: notesText)
        
        let service = AIChatService(provider: currentProvider, apiKey: cleanedAPIKey, model: currentModel)
        Task {
            do {
                for try await delta in service.askStream(input: prompt) {
                    await MainActor.run {
                        resultText += delta
                    }
                }
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }
    
    private func buildPrompt(for action: QuickAction, notes: String) -> String {
        switch action {
        case .summarize:
            return "请总结以下笔记内容，提炼核心观点：\n\n\(notes)"
        case .extractKeyPoints:
            return "请提取以下笔记中的关键要点，用清晰的列表呈现：\n\n\(notes)"
        case .generateTags:
            return "请为以下笔记推荐 3-5 个合适的标签，用中文：\n\n\(notes)"
        case .translate:
            return "请将以下内容翻译为中文（如果是中文则翻译为英文）：\n\n\(notes)"
        case .rewrite:
            return "请润色和改写以下内容，让它更清晰流畅：\n\n\(notes)"
        case .createFlashcards:
            return "请将以下内容制作成 Anki 闪卡格式（正面问题，背面答案）：\n\n\(notes)"
        }
    }
}

// MARK: - 辅助组件

struct NoteSelectionRow: View {
    let note: ReadingNote
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DesignSystem.Colors.primary : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.highlight)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        if let bookTitle = note.book?.title {
                            Text(bookTitle)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        if note.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.yellow)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? DesignSystem.Colors.primarySoft : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? DesignSystem.Colors.primary.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(DesignSystem.Colors.surfaceElevated.opacity(0.7))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(DesignSystem.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
