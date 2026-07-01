import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - 思维导图
//
// AI 自动从笔记生成树状大纲，可视化渲染为放射式思维导图。
// 数据结构：
//   MindMapNode { id, title, children, noteIDs }

// MARK: - 数据

struct MindMapNode: Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var detail: String?
    var children: [MindMapNode]
    var noteRefs: [UUID]
    var isHighlight: Bool = false

    static func == (lhs: MindMapNode, rhs: MindMapNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - 视图

struct MindMapView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var scope: MindScope = .all
    @State private var generatedTree: MindMapNode?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var selectedNodeID: UUID?
    @State private var saveStatus: String?

    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.openAI.rawValue
    @AppStorage("openAIModel") private var openAIModel = AIProvider.openAI.defaultModel
    @AppStorage("deepSeekModel") private var deepSeekModel = AIProvider.deepSeek.defaultModel
    @AppStorage("glmModel") private var glmModel = AIProvider.glm.defaultModel

    @Environment(\.themePalette) private var palette

    enum MindScope: String, CaseIterable, Identifiable {
        case all = "全部笔记"
        case book = "单本书"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)

            Text("思维导图")
                .font(.title3)
                .fontWeight(.semibold)

            Picker("范围", selection: $scope) {
                ForEach(MindScope.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Spacer()

            if isGenerating {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("AI 生成中...")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                Button {
                    Task { await generate() }
                } label: {
                    Label("AI 生成", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .disabled(appVM.allNotes.isEmpty)

                if generatedTree != nil {
                    Menu {
                        Button {
                            exportPNG()
                        } label: { Label("导出 PNG", systemImage: "photo") }
                        Button {
                            exportSVG()
                        } label: { Label("导出 SVG", systemImage: "doc.richtext") }
                        Button {
                            exportMarkdown()
                        } label: { Label("导出 Markdown 大纲", systemImage: "list.bullet.indent") }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 32)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - 主内容

    @ViewBuilder
    private var content: some View {
        if let tree = generatedTree {
            HSplitView {
                MindMapCanvas(root: tree, selectedID: $selectedNodeID)
                    .frame(minWidth: 380)
                nodeDetail
                    .frame(width: 320)
            }
        } else if isGenerating {
            VStack(spacing: 12) {
                ProgressView()
                Text("正在生成思维导图...")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(palette.warning)
                Text(errorMessage)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                Button("重试") { Task { await generate() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "还没生成思维导图",
                systemImage: "brain.head.profile",
                description: Text("点击 AI 生成，从你的笔记里抽出结构化大纲")
            )
        }
    }

    // MARK: - 节点详情

    @ViewBuilder
    private var nodeDetail: some View {
        if let id = selectedNodeID,
           let node = findNode(in: generatedTree, id: id) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(node.title)
                        .font(.title3)
                        .fontWeight(.bold)

                    if let detail = node.detail {
                        Text(detail)
                            .font(.callout)
                            .foregroundStyle(palette.textSecondary)
                    }

                    if !node.children.isEmpty {
                        Text("子节点 · \(node.children.count)")
                            .font(.caption)
                            .foregroundStyle(palette.textTertiary)
                            .padding(.top, 6)
                    }

                    if !node.noteRefs.isEmpty {
                        Text("引用笔记 · \(node.noteRefs.count)")
                            .font(.caption)
                            .foregroundStyle(palette.textTertiary)
                            .padding(.top, 6)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView(
                "选择节点",
                systemImage: "circle.dashed",
                description: Text("点击导图中的节点查看详情")
            )
        }
    }

    private func findNode(in node: MindMapNode?, id: UUID) -> MindMapNode? {
        guard let node else { return nil }
        if node.id == id { return node }
        for child in node.children {
            if let found = findNode(in: child, id: id) { return found }
        }
        return nil
    }

    // MARK: - 生成

    private func generate() async {
        guard !appVM.allNotes.isEmpty else {
            errorMessage = "请先导入笔记"
            return
        }
        guard let apiKey = KeychainService.loadAPIKey(for: currentProvider), !apiKey.isEmpty else {
            errorMessage = "请先在设置中配置 \(currentProvider.label) API Key"
            return
        }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let notes = appVM.allNotes.filter { !$0.isDeleted }
        let context = notes.prefix(80).map { note -> String in
            var s = "【\((note.book?.title ?? "未知") + (note.chapter.map { " · \($0)" } ?? ""))】\n\(note.highlight)"
            if let u = note.userNote, !u.isEmpty {
                s += "\n想法：\(u)"
            }
            return s
        }.joined(separator: "\n\n")

        let prompt = """
        基于以下笔记，生成一份结构化的思维导图大纲。

        要求：
        1. 中心主题：1 个
        2. 一级分支：3-6 个（核心主题）
        3. 每个一级分支下：2-5 个二级分支（具体论点）
        4. 必要时给二级分支加 1-3 个三级细节
        5. 输出严格 JSON 格式，不要任何其他文字

        JSON 格式：
        {
          "title": "中心主题",
          "summary": "一句话总结",
          "branches": [
            {
              "title": "一级分支",
              "summary": "一句话说明",
              "note_keywords": ["关键词1", "关键词2"],
              "children": [
                {
                  "title": "二级分支",
                  "summary": "一句话说明",
                  "note_keywords": ["关键词"]
                }
              ]
            }
          ]
        }

        笔记：
        \(context)
        """

        let service = AIChatService(provider: currentProvider, apiKey: apiKey, model: currentModel)

        do {
            var collected = ""
            for try await chunk in service.askStream(input: prompt) {
                collected += chunk
            }
            // 提取 JSON
            if let jsonStart = collected.firstIndex(of: "{"),
               let jsonEnd = collected.lastIndex(of: "}") {
                let jsonStr = String(collected[jsonStart...jsonEnd])
                if let data = jsonStr.data(using: .utf8),
                   let parsed = try? JSONDecoder().decode(MindMapJSON.self, from: data) {
                    generatedTree = parsed.toMindMapNode()
                    return
                }
            }
            errorMessage = "AI 返回内容解析失败，请重试"
        } catch {
            errorMessage = error.localizedDescription
        }
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

    // MARK: - 导出

    private func exportPNG() {
        guard let tree = generatedTree else { return }
        #if canImport(AppKit)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "思维导图-\(Date().shortString).png"
        if panel.runModal() == .OK, let url = panel.url {
            let view = MindMapExportView(root: tree)
                .frame(width: 1600, height: 1000)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2.0
            if let nsImage = renderer.nsImage,
               let tiff = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
                saveStatus = "已导出 PNG：\(url.lastPathComponent)"
            }
        }
        #endif
    }

    private func exportSVG() {
        guard let tree = generatedTree else { return }
        #if canImport(AppKit)
        let panel = NSSavePanel()
        if let svgType = UTType(filenameExtension: "svg") {
            panel.allowedContentTypes = [svgType]
        }
        panel.nameFieldStringValue = "思维导图-\(Date().shortString).svg"
        if panel.runModal() == .OK, let url = panel.url {
            let svg = renderSVG(root: tree)
            try? svg.write(to: url, atomically: true, encoding: .utf8)
            saveStatus = "已导出 SVG：\(url.lastPathComponent)"
        }
        #endif
    }

    private func exportMarkdown() {
        guard let tree = generatedTree else { return }
        #if canImport(AppKit)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .text]
        panel.nameFieldStringValue = "思维导图-\(Date().shortString).md"
        if panel.runModal() == .OK, let url = panel.url {
            let md = renderMarkdown(root: tree)
            try? md.write(to: url, atomically: true, encoding: .utf8)
            saveStatus = "已导出 Markdown：\(url.lastPathComponent)"
        }
        #endif
    }

    private func renderMarkdown(root: MindMapNode) -> String {
        var md = "# \(root.title)\n\n"
        if let detail = root.detail {
            md += "> \(detail)\n\n"
        }
        md += renderChildren(root.children, depth: 1)
        return md
    }

    private func renderChildren(_ nodes: [MindMapNode], depth: Int) -> String {
        var md = ""
        for node in nodes {
            md += String(repeating: "  ", count: depth) + "- "
            md += "**\(node.title)**"
            if let detail = node.detail {
                md += " — \(detail)"
            }
            md += "\n"
            md += renderChildren(node.children, depth: depth + 1)
        }
        return md
    }

    private func renderSVG(root: MindMapNode) -> String {
        // 简易放射式 SVG
        let width = 1200.0
        let height = 900.0
        let cx = width / 2
        let cy = height / 2
        let radius = 350.0

        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(width)) \(Int(height))" font-family="-apple-system, sans-serif">
        <rect width="\(Int(width))" height="\(Int(height))" fill="#0F1115"/>
        """

        let branches = root.children
        let branchCount = max(1, branches.count)

        // 边
        for (i, branch) in branches.enumerated() {
            let angle = (Double(i) / Double(branchCount)) * .pi * 2 - .pi / 2
            let x2 = cx + cos(angle) * radius
            let y2 = cy + sin(angle) * radius
            svg += "\n<line x1=\"\(Int(cx))\" y1=\"\(Int(cy))\" x2=\"\(Int(x2))\" y2=\"\(Int(y2))\" stroke=\"#5B8DEF\" stroke-width=\"1.5\" opacity=\"0.6\"/>"

            let subRadius = radius * 0.55
            let subCount = max(1, branch.children.count)
            for (j, sub) in branch.children.enumerated() {
                let subAngle = angle + (Double(j) - Double(subCount - 1) / 2) * 0.4
                let sx = x2 + cos(subAngle) * subRadius
                let sy = y2 + sin(subAngle) * subRadius
                svg += "\n<line x1=\"\(Int(x2))\" y1=\"\(Int(y2))\" x2=\"\(Int(sx))\" y2=\"\(Int(sy))\" stroke=\"#5B8DEF\" stroke-width=\"1\" opacity=\"0.4\"/>"
                svg += "\n<circle cx=\"\(Int(sx))\" cy=\"\(Int(sy))\" r=\"4\" fill=\"#7AD89E\"/>"
                svg += "\n<text x=\"\(Int(sx))\" y=\"\(Int(sy) + 18)\" fill=\"#E0E0E0\" font-size=\"11\" text-anchor=\"middle\">\(escape(sub.title))</text>"
            }

            svg += "\n<circle cx=\"\(Int(x2))\" y=\"\(Int(y2))\" r=\"6\" fill=\"#5B8DEF\"/>"
            svg += "\n<text x=\"\(Int(x2))\" y=\"\(Int(y2) + 20)\" fill=\"#FFFFFF\" font-size=\"13\" text-anchor=\"middle\" font-weight=\"600\">\(escape(branch.title))</text>"
        }

        // 中心节点
        svg += "\n<circle cx=\"\(Int(cx))\" cy=\"\(Int(cy))\" r=\"30\" fill=\"#5B8DEF\"/>"
        svg += "\n<text x=\"\(Int(cx))\" y=\"\(Int(cy) + 45)\" fill=\"#FFFFFF\" font-size=\"16\" text-anchor=\"middle\" font-weight=\"700\">\(escape(root.title))</text>"

        svg += "\n</svg>"
        return svg
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - 思维导图导出视图（高清截图用）

struct MindMapExportView: View {
    let root: MindMapNode
    @Environment(\.themePalette) private var palette

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            HStack(alignment: .top, spacing: 0) {
                MindMapCanvas(root: root, selectedID: .constant(nil))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - JSON 模型

struct MindMapJSON: Decodable {
    let title: String
    let summary: String?
    let branches: [BranchJSON]

    struct BranchJSON: Decodable {
        let title: String
        let summary: String?
        let note_keywords: [String]?
        let children: [BranchJSON]?
    }

    func toMindMapNode() -> MindMapNode {
        let root = MindMapNode(
            id: UUID(),
            title: title,
            detail: summary,
            children: branches.map { $0.toNode(parent: "") },
            noteRefs: []
        )
        return root
    }
}

extension MindMapJSON.BranchJSON {
    func toNode(parent: String) -> MindMapNode {
        MindMapNode(
            id: UUID(),
            title: title,
            detail: summary,
            children: (children ?? []).map { $0.toNode(parent: title) },
            noteRefs: []
        )
    }
}

// MARK: - 思维导图 Canvas

struct MindMapCanvas: View {
    let root: MindMapNode
    @Binding var selectedID: UUID?

    @Environment(\.themePalette) private var palette

    var body: some View {
        GeometryReader { geo in
            let layout = MindLayout.compute(root: root, in: geo.size)
            ZStack {
                // 边
                edges(layout: layout)
                // 节点
                nodes(layout: layout)
            }
            .background(palette.surface.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func edges(layout: MindLayout) -> some View {
        Canvas { ctx, _ in
            for edge in layout.edges {
                var path = Path()
                path.move(to: edge.from)
                // 中点拐弯
                let mid = CGPoint(x: edge.to.x, y: edge.from.y)
                path.addLine(to: mid)
                path.addLine(to: edge.to)
                ctx.stroke(
                    path,
                    with: .color(palette.borderMedium.opacity(0.7)),
                    lineWidth: 1.5
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func nodes(layout: MindLayout) -> some View {
        ZStack {
            ForEach(layout.nodes) { item in
                nodeView(node: item.node, position: item.position, depth: item.depth)
                    .position(item.position)
            }
        }
    }

    private func nodeView(node: MindMapNode, position: CGPoint, depth: Int) -> some View {
        let isSelected = selectedID == node.id
        let isRoot = depth == 0

        return Button {
            selectedID = node.id
        } label: {
            VStack(spacing: 2) {
                Text(node.title)
                    .font(.system(size: isRoot ? 14 : depth == 1 ? 12 : 11,
                                  weight: isRoot ? .bold : .medium))
                    .foregroundStyle(isRoot ? .white : palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if let detail = node.detail, !detail.isEmpty, isSelected {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(isRoot ? .white.opacity(0.85) : palette.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, isRoot ? 18 : 12)
            .padding(.vertical, isRoot ? 12 : 8)
            .background(
                RoundedRectangle(cornerRadius: isRoot ? 14 : 8, style: .continuous)
                    .fill(isRoot ? AnyShapeStyle(palette.accent.gradient) : AnyShapeStyle(isSelected ? AnyShapeStyle(palette.accent.opacity(0.20)) : AnyShapeStyle(palette.surfaceElevated)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isRoot ? 14 : 8, style: .continuous)
                    .stroke(isSelected ? palette.accent : palette.borderSubtle,
                            lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(isRoot ? 0.20 : 0.08),
                    radius: isRoot ? 8 : 3, y: isRoot ? 4 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 布局算法

struct MindLayout {
    struct NodeItem: Identifiable {
        var id: UUID { node.id }
        let node: MindMapNode
        let position: CGPoint
        let depth: Int
    }

    struct Edge {
        let from: CGPoint
        let to: CGPoint
    }

    let nodes: [NodeItem]
    let edges: [Edge]

    static func compute(root: MindMapNode, in size: CGSize) -> MindLayout {
        var nodeItems: [NodeItem] = []
        var edges: [Edge] = []

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let rootSize = CGSize(width: 140, height: 50)

        nodeItems.append(NodeItem(node: root, position: center, depth: 0))

        // 计算每个一级分支的角度
        let branches = root.children
        guard !branches.isEmpty else { return MindLayout(nodes: nodeItems, edges: edges) }

        let radius: CGFloat = min(size.width, size.height) * 0.32

        for (i, branch) in branches.enumerated() {
            let angle = (CGFloat(i) / CGFloat(branches.count)) * .pi * 2 - .pi / 2
            let branchPos = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            edges.append(Edge(from: center, to: branchPos))
            nodeItems.append(NodeItem(node: branch, position: branchPos, depth: 1))

            // 二级分支
            let subRadius = radius * 0.55
            for (j, sub) in branch.children.enumerated() {
                let subCount = branch.children.count
                let subAngle = angle + (CGFloat(j) - CGFloat(subCount - 1) / 2) * 0.35
                let subPos = CGPoint(
                    x: branchPos.x + cos(subAngle) * subRadius,
                    y: branchPos.y + sin(subAngle) * subRadius
                )
                edges.append(Edge(from: branchPos, to: subPos))
                nodeItems.append(NodeItem(node: sub, position: subPos, depth: 2))
            }
        }

        return MindLayout(nodes: nodeItems, edges: edges)
    }
}