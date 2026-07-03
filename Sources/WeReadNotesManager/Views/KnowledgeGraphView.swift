import SwiftUI
import SwiftData

// MARK: - 图数据

struct KGNode: Identifiable, Equatable {
    let id: String
    let title: String
    let type: KGNodeType
    let color: Color
    var x: CGFloat
    var y: CGFloat

    static func == (lhs: KGNode, rhs: KGNode) -> Bool { lhs.id == rhs.id }
}

enum KGNodeType: String {
    case book
    case topic
    case tag
}

struct KGEdge: Identifiable {
    let id = UUID()
    let source: String
    let target: String
    let strength: CGFloat
}

// MARK: - 图构建服务

@MainActor
struct KnowledgeGraphBuilder {
    func build(books: [Book], tags: [Tag], clusters: [TopicCluster]) -> (nodes: [KGNode], edges: [KGEdge]) {
        var nodes: [KGNode] = []
        var edges: [KGEdge] = []
        var nodeIndexByID: [String: Int] = [:]

        // 书籍节点
        for book in books where !book.notes.isEmpty {
            let id = book.id.uuidString
            let node = KGNode(
                id: id,
                title: book.title,
                type: .book,
                color: .blue,
                x: .zero,
                y: .zero
            )
            nodeIndexByID[id] = nodes.count
            nodes.append(node)
        }

        // 主题节点
        for cluster in clusters where cluster.noteIDs.count >= 2 {
            let id = cluster.id.uuidString
            let node = KGNode(
                id: id,
                title: cluster.name,
                type: .topic,
                color: .green,
                x: .zero,
                y: .zero
            )
            nodeIndexByID[id] = nodes.count
            nodes.append(node)

            let relatedBooks = Set(cluster.noteIDs.compactMap { noteID -> String? in
                books.first { book in
                    book.notes.contains { $0.id == noteID }
                }?.id.uuidString
            })
            for bookID in relatedBooks {
                if nodeIndexByID[bookID] != nil {
                    edges.append(KGEdge(source: id, target: bookID, strength: 0.6))
                }
            }
        }

        // 标签节点（与书籍共现）
        for tag in tags where tag.notes.count >= 2 {
            let id = tag.id
            let node = KGNode(
                id: id,
                title: tag.name,
                type: .tag,
                color: colorFor(tag),
                x: .zero,
                y: .zero
            )
            nodeIndexByID[id] = nodes.count
            nodes.append(node)

            let relatedBooks = Set(tag.notes.compactMap { note -> String? in
                note.book?.id.uuidString
            })
            for bookID in relatedBooks {
                if nodeIndexByID[bookID] != nil {
                    edges.append(KGEdge(source: id, target: bookID, strength: 0.4))
                }
            }
        }

        // 书籍之间的边：共享主题
        var bookPairCounts: [String: Int] = [:]
        for edge in edges where nodes[nodeIndexByID[edge.source] ?? 0].type == .topic {
            let relatedBooks = edges
                .filter { $0.source == edge.source || $0.target == edge.source }
                .compactMap { e -> String? in
                    let other = e.source == edge.source ? e.target : e.source
                    return nodes[nodeIndexByID[other] ?? 0].type == .book ? other : nil
                }
            for i in 0..<relatedBooks.count {
                for j in (i + 1)..<relatedBooks.count {
                    let key = [relatedBooks[i], relatedBooks[j]].sorted().joined(separator: "-")
                    bookPairCounts[key, default: 0] += 1
                }
            }
        }
        for (key, count) in bookPairCounts where count >= 2 {
            let ids = key.split(separator: "-").map { String($0) }
            guard ids.count == 2 else { continue }
            edges.append(KGEdge(source: ids[0], target: ids[1], strength: min(1.0, 0.2 + CGFloat(count) * 0.15)))
        }

        return (nodes, edges)
    }
}

// MARK: - 力导向布局

struct ForceLayout {
    static func solve(nodes: inout [KGNode], edges: [KGEdge], size: CGSize, iterations: Int = 80) {
        let width = size.width
        let height = size.height
        let centerX = width / 2
        let centerY = height / 2

        for i in 0..<nodes.count {
            nodes[i].x = centerX + CGFloat.random(in: -80...80)
            nodes[i].y = centerY + CGFloat.random(in: -80...80)
        }

        let nodeIndex: [String: Int] = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) })

        for _ in 0..<iterations {
            var forces: [CGPoint] = Array(repeating: .zero, count: nodes.count)

            for i in 0..<nodes.count {
                for j in (i + 1)..<nodes.count {
                    let dx = nodes[i].x - nodes[j].x
                    let dy = nodes[i].y - nodes[j].y
                    let dist = sqrt(dx * dx + dy * dy) + 0.01
                    let force: CGFloat = 3000 / (dist * dist)
                    let fx = (dx / dist) * force
                    let fy = (dy / dist) * force
                    forces[i].x += fx
                    forces[i].y += fy
                    forces[j].x -= fx
                    forces[j].y -= fy
                }
            }

            for edge in edges {
                guard let si = nodeIndex[edge.source], let ti = nodeIndex[edge.target] else { continue }
                let dx = nodes[ti].x - nodes[si].x
                let dy = nodes[ti].y - nodes[si].y
                let dist = sqrt(dx * dx + dy * dy) + 0.01
                let targetLength: CGFloat = 80 + (1 - edge.strength) * 60
                let force = (dist - targetLength) * 0.03
                let fx = (dx / dist) * force
                let fy = (dy / dist) * force
                forces[si].x += fx
                forces[si].y += fy
                forces[ti].x -= fx
                forces[ti].y -= fy
            }

            for i in 0..<nodes.count {
                let dx = centerX - nodes[i].x
                let dy = centerY - nodes[i].y
                forces[i].x += dx * 0.005
                forces[i].y += dy * 0.005
            }

            for i in 0..<nodes.count {
                nodes[i].x += forces[i].x
                nodes[i].y += forces[i].y
                nodes[i].x = min(max(nodes[i].x, 30), width - 30)
                nodes[i].y = min(max(nodes[i].y, 30), height - 30)
            }
        }
    }
}

// MARK: - 视图

struct KnowledgeGraphView: View {
    @Environment(AppViewModel.self) private var appVM
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query(sort: \TopicCluster.updatedAt, order: .reverse) private var clusters: [TopicCluster]
    @Environment(\.themePalette) private var palette

    @State private var nodes: [KGNode] = []
    @State private var edges: [KGEdge] = []
    @State private var selectedNode: KGNode?
    @State private var isComputing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("知识图谱")
                    .font(.system(size: 20, weight: .semibold))
                Text("书籍 · 主题 · 标签的关系网络")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                LegendItem(color: .blue, label: "书籍")
                LegendItem(color: .green, label: "主题")
                LegendItem(color: .orange, label: "标签")
            }
            Button {
                Task { computeGraph() }
            } label: {
                Label("重新布局", systemImage: "arrow.clockwise")
            }
            .flatActionButton(.accent, height: 32)
            .disabled(isComputing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var content: some View {
        GeometryReader { geo in
            ZStack {
                edgesLayer
                nodesLayer(in: geo.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.surface.opacity(0.3))
            .onAppear {
                computeGraph(size: geo.size)
            }
            .onChange(of: geo.size) { _, newSize in
                computeGraph(size: newSize)
            }
        }
    }

    private var edgesLayer: some View {
        Canvas { ctx, _ in
            for edge in edges {
                guard let source = nodes.first(where: { $0.id == edge.source }),
                      let target = nodes.first(where: { $0.id == edge.target }) else { continue }

                var path = Path()
                path.move(to: CGPoint(x: source.x, y: source.y))
                path.addLine(to: CGPoint(x: target.x, y: target.y))

                ctx.stroke(
                    path,
                    with: .color(palette.borderMedium.opacity(0.3 + Double(edge.strength) * 0.4)),
                    lineWidth: 0.5 + edge.strength * 1.5
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func nodesLayer(in size: CGSize) -> some View {
        ZStack {
            ForEach(nodes) { node in
                Button {
                    selectedNode = node
                } label: {
                    VStack(spacing: 3) {
                        Circle()
                            .fill(node.color)
                            .frame(width: nodeSize(for: node), height: nodeSize(for: node))
                            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                        Text(node.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(2)
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                    }
                }
                .buttonStyle(.plain)
                .position(x: node.x, y: node.y)
            }
        }
        .overlay(alignment: .trailing) {
            if let selectedNode {
                nodeDetailPanel(node: selectedNode)
                    .frame(width: 260)
                    .padding(.trailing, 16)
            }
        }
    }

    private func nodeSize(for node: KGNode) -> CGFloat {
        switch node.type {
        case .book: return 18
        case .topic: return 14
        case .tag: return 10
        }
    }

    private func nodeDetailPanel(node: KGNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(node.title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    self.selectedNode = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(typeLabel(for: node))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            let related = edges.filter { $0.source == node.id || $0.target == node.id }
            if !related.isEmpty {
                Text("关联 (\(related.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.top, 4)

                ForEach(related.prefix(8), id: \.id) { edge in
                    let otherID = edge.source == node.id ? edge.target : edge.source
                    if let other = nodes.first(where: { $0.id == otherID }) {
                        Button {
                            self.selectedNode = other
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(other.color)
                                    .frame(width: 6, height: 6)
                                Text(other.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(palette.surfaceElevated)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                navigateToNode(node)
            } label: {
                Label("查看详情", systemImage: "arrow.right")
            }
            .flatActionButton(.accent, height: 28)
            .controlSize(.small)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.background)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.borderSubtle, lineWidth: 0.5))
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    private func typeLabel(for node: KGNode) -> String {
        switch node.type {
        case .book: return "书籍"
        case .topic: return "主题簇"
        case .tag: return "标签"
        }
    }

    private func navigateToNode(_ node: KGNode) {
        switch node.type {
        case .book:
            if let book = books.first(where: { $0.id.uuidString == node.id }) {
                appVM.selectedBook = book
                appVM.selectedSidebarItem = .books
            }
        case .topic:
            if clusters.first(where: { $0.id.uuidString == node.id }) != nil {
                appVM.selectedSidebarItem = .topicClusters
            }
        case .tag:
            appVM.selectedSidebarItem = .tags
        }
        selectedNode = nil
    }

    private func computeGraph(size: CGSize? = nil) {
        isComputing = true
        let builder = KnowledgeGraphBuilder()
        var (newNodes, newEdges) = builder.build(books: books, tags: tags, clusters: clusters)

        let containerSize = size ?? CGSize(width: 800, height: 600)
        ForceLayout.solve(nodes: &newNodes, edges: newEdges, size: containerSize)

        nodes = newNodes
        edges = newEdges
        selectedNode = nil
        isComputing = false
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
