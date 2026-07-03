import SwiftUI
import SwiftData

/// 主题聚类视图：本地 embedding 聚类 + AI 命名摘要。
struct TopicClustersView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themePalette) private var palette
    @Query(sort: \TopicCluster.updatedAt, order: .reverse) private var clusters: [TopicCluster]

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var selectedCluster: TopicCluster?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                clusterList
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
                Divider()
                clusterDetail
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("主题聚类")
                    .font(.system(size: 20, weight: .semibold))
                Text("基于语义相似度自动发现跨书主题")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isGenerating {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("聚类中...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                Task { await generateClusters() }
            } label: {
                Label("重新聚类", systemImage: "sparkles")
            }
            .flatActionButton(.accent, height: 32)
            .disabled(isGenerating || appVM.allNotes.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var clusterList: some View {
        List(selection: $selectedCluster) {
            if clusters.isEmpty {
                ContentUnavailableView(
                    "还没有主题簇",
                    systemImage: "circle.grid.2x2",
                    description: Text("点击重新聚类生成")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(clusters) { cluster in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cluster.name)
                            .font(.system(size: 14, weight: .semibold))
                        if let summary = cluster.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        HStack(spacing: 6) {
                            Text("\(cluster.noteIDs.count) 条笔记")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            if !cluster.keywords.isEmpty {
                                Text(cluster.keywords.prefix(3).joined(separator: " · "))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(cluster)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var clusterDetail: some View {
        ScrollView {
            if let cluster = selectedCluster ?? clusters.first {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cluster.name)
                                .font(.system(size: 22, weight: .bold))
                            if let summary = cluster.summary, !summary.isEmpty {
                                Text(summary)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(cluster.noteIDs.count) 条笔记")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(palette.surfaceElevated)
                                    .overlay(Capsule().stroke(palette.borderSubtle, lineWidth: 0.5))
                            )
                    }

                    if !cluster.keywords.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(cluster.keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(palette.accent.opacity(0.12))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(palette.accent.opacity(0.3), lineWidth: 0.5)
                                    )
                            }
                        }
                    }

                    Divider()

                    let notes = resolveNotes(ids: cluster.noteIDs)
                    ForEach(notes) { note in
                        clusterNoteRow(note: note)
                    }
                }
                .padding(20)
            } else {
                ContentUnavailableView(
                    "选择主题查看详情",
                    systemImage: "circle.grid.2x2",
                    description: Text("主题聚类基于本地 embedding 语义相似度")
                )
                .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
    }

    private func clusterNoteRow(note: ReadingNote) -> some View {
        Button {
            appVM.selectedBook = note.book
            appVM.selectedNote = note
            appVM.selectedSidebarItem = .books
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                if let bookTitle = note.book?.title {
                    Text(bookTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(note.highlight)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                if let userNote = note.userNote, !userNote.isEmpty {
                    Text(userNote)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(palette.borderSubtle, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func resolveNotes(ids: [UUID]) -> [ReadingNote] {
        let descriptor = FetchDescriptor<ReadingNote>()
        guard let all = try? modelContext.fetch(descriptor) else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    private func generateClusters() async {
        guard let apiKey = currentAPIKey, !apiKey.isEmpty else {
            errorMessage = "请先在设置中配置 AI API Key（用于主题命名）"
            return
        }

        let notes = appVM.allNotes.filter { !$0.isDeleted }
        guard notes.count >= 3 else {
            errorMessage = "至少需要 3 条笔记才能聚类"
            return
        }

        isGenerating = true
        errorMessage = nil

        // 删除旧聚类
        for cluster in clusters {
            modelContext.delete(cluster)
        }
        try? modelContext.save()

        let service = TopicClusteringService.shared
        let groups = service.cluster(notes: notes, k: 6)

        let runner = makeRunner(apiKey: apiKey)

        for indices in groups where indices.count >= 2 {
            let groupNotes = indices.map { notes[$0] }
            let keywords = service.keywords(for: notes, indices: indices)

            let input = TopicNamingInput(
                notes: groupNotes.map { TopicNamingNote(highlight: $0.highlight, userNote: $0.userNote) },
                keywords: keywords
            )

            do {
                let naming = try await runner.run(TopicNamingTask(), input: input)
                let cluster = TopicCluster(
                    name: naming.name,
                    summary: naming.summary,
                    noteIDs: groupNotes.map { $0.id },
                    keywords: keywords
                )
                modelContext.insert(cluster)
            } catch {
                // 命名失败时 fallback
                let cluster = TopicCluster(
                    name: "主题 \(keywords.first ?? "未命名")",
                    summary: "包含 \(groupNotes.count) 条相关笔记",
                    noteIDs: groupNotes.map { $0.id },
                    keywords: keywords
                )
                modelContext.insert(cluster)
            }
        }

        try? modelContext.save()
        isGenerating = false
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
