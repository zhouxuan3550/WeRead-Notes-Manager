import SwiftUI

// MARK: - Skeleton 骨架屏
//
// 数据加载时显示的占位 UI：
// - 灰色渐变条
// - 微光扫过动画（shimmer）
// - 真实加载完成后消失（带渐显过渡）
//
// 比直接显示空白 / 转圈更专业。

// MARK: - 基础 Shimmer Modifier

struct SkeletonShimmer: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.35),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.5)
                    .blendMode(.plusLighter)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

// MARK: - 基础 Skeleton 元素

struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 4
    @Environment(\.themePalette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.surface.opacity(0.6),
                        palette.surfaceElevated.opacity(0.9),
                        palette.surface.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .modifier(SkeletonShimmer())
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40
    @Environment(\.themePalette) private var palette

    var body: some View {
        Circle()
            .fill(palette.surfaceElevated.opacity(0.7))
            .frame(width: size, height: size)
            .modifier(SkeletonShimmer())
    }
}

// MARK: - 笔记列表骨架

struct NoteListSkeleton: View {
    var count: Int = 5

    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(alignment: .top, spacing: 12) {
                    SkeletonCircle(size: 32)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBar(width: 80, height: 11)
                        SkeletonBar(height: 14)
                        SkeletonBar(width: 220, height: 14)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.surface.opacity(0.4))
        )
    }
}

// MARK: - 仪表盘骨架

struct DashboardSkeleton: View {
    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                SkeletonBar(width: 100, height: 18)
                Spacer()
                SkeletonBar(width: 80, height: 18)
            }

            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 8) {
                        SkeletonBar(height: 40)
                        SkeletonBar(height: 14)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(palette.surface.opacity(0.4))
                    )
                }
            }

            HStack(spacing: 12) {
                ForEach(0..<8, id: \.self) { _ in
                    SkeletonBar(width: 70, height: 100)
                }
            }
        }
    }
}

// MARK: - 带状态切换的容器

struct AsyncContentView<Content: View, Skeleton: View>: View {
    enum State {
        case loading
        case loaded
        case empty
        case error(String)
    }

    let state: State
    let skeleton: () -> Skeleton
    let content: () -> Content
    let empty: () -> AnyView

    init(
        state: State,
        @ViewBuilder skeleton: @escaping () -> Skeleton,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder empty: @escaping () -> some View
    ) {
        self.state = state
        self.skeleton = skeleton
        self.content = content
        self.empty = { AnyView(empty()) }
    }

    @Environment(\.themePalette) private var palette

    var body: some View {
        ZStack {
            switch state {
            case .loading:
                skeleton()
                    .transition(.opacity)
            case .loaded:
                content()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .empty:
                empty()
                    .transition(.opacity)
            case .error(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(palette.warning)
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: stateIsLoaded)
    }

    private var stateIsLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }
}

// MARK: - View 扩展

extension View {
    /// 视图级 skeleton 切换
    func skeleton<SkeletonContent: View>(
        isLoading: Bool,
        @ViewBuilder skeleton: @escaping () -> SkeletonContent
    ) -> some View {
        ZStack {
            if isLoading {
                skeleton()
                    .transition(.opacity)
            } else {
                self.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}