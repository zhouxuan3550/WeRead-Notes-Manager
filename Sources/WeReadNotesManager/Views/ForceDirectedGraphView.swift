import SwiftUI

// MARK: - 主题力导向图
//
// 把 ReadingInsightService 输出的 ThemeCluster 渲染成力导向图：
// 节点大小 = 笔记数量，颜色 = 调色板；
// 自动布局（基于 Spring System / Repulsion 算法）。
//
// Canvas 渲染，零依赖，60fps。

// MARK: - 图节点

struct GraphNode: Identifiable, Equatable {
    let id: String
    let label: String
    let weight: Int
    var position: CGPoint
    var velocity: CGPoint = .zero
}

struct GraphEdge: Identifiable, Equatable {
    let id: String
    let source: String
    let target: String
}

// MARK: - 视图

struct ForceDirectedGraphView: View {
    let clusters: [ThemeCluster]

    @Environment(\.themePalette) private var palette
    @State private var nodes: [GraphNode] = []
    @State private var edges: [GraphEdge] = []
    @State private var hoverNodeID: String?
    @State private var size: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                edgesView
                nodesView
            }
            .background(palette.surface.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onAppear {
                size = geo.size
                rebuildGraph(size: geo.size)
                startSimulation()
            }
            .onChange(of: geo.size) { _, newSize in
                size = newSize
            }
        }
        .frame(minHeight: 320)
        .onChange(of: clusters) { _, _ in
            rebuildGraph(size: size)
            startSimulation()
        }
    }

    // MARK: - 节点渲染

    private var nodesView: some View {
        Canvas { ctx, _ in
            for node in nodes {
                let radius = nodeRadius(for: node)
                let isHovered = node.id == hoverNodeID
                let color = palette.accent

                // 外发光（hover 时）
                if isHovered {
                    let glowRadius = radius * 2.2
                    let glow = ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: node.position.x - glowRadius,
                            y: node.position.y - glowRadius,
                            width: glowRadius * 2,
                            height: glowRadius * 2
                        )),
                        with: .color(color.opacity(0.18))
                    )
                    _ = glow
                }

                // 主节点
                let rect = CGRect(
                    x: node.position.x - radius,
                    y: node.position.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.85)))
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(palette.surface.opacity(0.6)),
                    lineWidth: 2
                )

                // 文字（hover 时显示）
                if isHovered {
                    let label = "\(node.label) · \(node.weight)"
                    var text = Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(palette.textPrimary)
                    ctx.draw(
                        text,
                        at: CGPoint(x: node.position.x, y: node.position.y + radius + 14),
                        anchor: .center
                    )
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    updateHover(at: value.location)
                }
                .onEnded { _ in
                    hoverNodeID = nil
                }
        )
    }

    // MARK: - 边渲染

    private var edgesView: some View {
        Canvas { ctx, _ in
            for edge in edges {
                guard let source = nodes.first(where: { $0.id == edge.source }),
                      let target = nodes.first(where: { $0.id == edge.target }) else { continue }
                var path = Path()
                path.move(to: source.position)
                path.addLine(to: target.position)
                ctx.stroke(
                    path,
                    with: .color(palette.borderMedium.opacity(0.5)),
                    lineWidth: 1.0
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 物理模拟

    private func startSimulation() {
        // 单帧迭代，避免 Task 占用线程
        for _ in 0..<120 {
            stepSimulation()
        }
    }

    private func stepSimulation() {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let repulsion: CGFloat = 3800
        let springLength: CGFloat = 110
        let springK: CGFloat = 0.04
        let damping: CGFloat = 0.78
        let centerPull: CGFloat = 0.012

        // 节点间斥力
        for i in 0..<nodes.count {
            var force = CGPoint.zero
            for j in 0..<nodes.count where i != j {
                let dx = nodes[i].position.x - nodes[j].position.x
                let dy = nodes[i].position.y - nodes[j].position.y
                let dist = max(8, sqrt(dx * dx + dy * dy))
                let f = repulsion / (dist * dist)
                force.x += dx / dist * f
                force.y += dy / dist * f
            }
            // 中心拉力
            let dx = center.x - nodes[i].position.x
            let dy = center.y - nodes[i].position.y
            force.x += dx * centerPull
            force.y += dy * centerPull
            nodes[i].velocity.x = (nodes[i].velocity.x + force.x) * damping
            nodes[i].velocity.y = (nodes[i].velocity.y + force.y) * damping
        }

        // 边弹簧
        for edge in edges {
            guard let sIdx = nodes.firstIndex(where: { $0.id == edge.source }),
                  let tIdx = nodes.firstIndex(where: { $0.id == edge.target }) else { continue }
            let dx = nodes[tIdx].position.x - nodes[sIdx].position.x
            let dy = nodes[tIdx].position.y - nodes[sIdx].position.y
            let dist = max(8, sqrt(dx * dx + dy * dy))
            let diff = dist - springLength
            let fx = (dx / dist) * diff * springK
            let fy = (dy / dist) * diff * springK
            nodes[sIdx].velocity.x += fx
            nodes[sIdx].velocity.y += fy
            nodes[tIdx].velocity.x -= fx
            nodes[tIdx].velocity.y -= fy
        }

        // 应用速度
        for i in 0..<nodes.count {
            nodes[i].position.x += nodes[i].velocity.x
            nodes[i].position.y += nodes[i].velocity.y
            // 边界约束
            let r = nodeRadius(for: nodes[i])
            nodes[i].position.x = min(size.width - r, max(r, nodes[i].position.x))
            nodes[i].position.y = min(size.height - r, max(r, nodes[i].position.y))
        }
    }

    private func nodeRadius(for node: GraphNode) -> CGFloat {
        let base: CGFloat = 12
        let scale: CGFloat = 14
        return base + CGFloat(node.weight) * scale / 30
    }

    private func updateHover(at point: CGPoint) {
        var found: String?
        for node in nodes {
            let r = nodeRadius(for: node)
            let dx = point.x - node.position.x
            let dy = point.y - node.position.y
            if dx * dx + dy * dy <= r * r * 1.2 {
                found = node.id
                break
            }
        }
        hoverNodeID = found
    }

    // MARK: - 构建图

    private func rebuildGraph(size: CGSize) {
        let cx = size.width / 2
        let cy = size.height / 2
        let count = max(1, clusters.count)
        let radius = min(size.width, size.height) * 0.32

        nodes = clusters.enumerated().map { idx, cluster in
            let angle = (Double(idx) / Double(count)) * .pi * 2
            let x = cx + cos(angle) * radius + CGFloat.random(in: -30...30)
            let y = cy + sin(angle) * radius + CGFloat.random(in: -30...30)
            return GraphNode(
                id: cluster.id,
                label: cluster.title,
                weight: cluster.count,
                position: CGPoint(x: x, y: y)
            )
        }

        // 边：每个主题与共享的笔记数量最多的两本书/其他主题相连
        var edges: [GraphEdge] = []
        for i in 0..<clusters.count {
            for j in (i + 1)..<clusters.count {
                // 共享书籍数
                let sharedBooks = Set(clusters[i].books.map(\.id)).intersection(Set(clusters[j].books.map(\.id))).count
                if sharedBooks > 0 {
                    edges.append(GraphEdge(
                        id: "\(clusters[i].id)-\(clusters[j].id)",
                        source: clusters[i].id,
                        target: clusters[j].id
                    ))
                }
            }
        }
        self.edges = edges
    }
}