import SwiftUI

// MARK: - 3D 书架 CoverFlow
//
// 仿 Apple CoverFlow / iTunes 视觉：
// - 中心书最大，向两边递减
// - 两侧书 3D 旋转（Y 轴）
// - 滚动 / 拖动切换选中
// - 点击选中书进入详情

struct CoverFlowView: View {
    let books: [Book]
    @Binding var selectedBookID: UUID?
    let onSelect: (Book) -> Void

    @Environment(\.themePalette) private var palette
    @State private var currentIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0

    private let bookWidth: CGFloat = 180
    private let bookHeight: CGFloat = 250
    private let spacing: CGFloat = 40

    init(books: [Book], selectedBookID: Binding<UUID?>, onSelect: @escaping (Book) -> Void) {
        self.books = books
        self._selectedBookID = selectedBookID
        self.onSelect = onSelect
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 顶部光晕
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [palette.accent.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 300
                        )
                    )
                    .frame(height: 200)
                    .offset(y: -50)

                ForEach(Array(books.enumerated()), id: \.element.id) { idx, book in
                    cover(book: book, index: idx, in: geo.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width < -threshold {
                            move(by: 1)
                        } else if value.translation.width > threshold {
                            move(by: -1)
                        }
                    }
            )
            .overlay(alignment: .bottom) {
                if currentIndex < books.count {
                    bookInfo(books[currentIndex])
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            if let id = selectedBookID, let idx = books.firstIndex(where: { $0.id == id }) {
                currentIndex = idx
            }
        }
    }

    // MARK: - 单本书渲染

    private func cover(book: Book, index: Int, in size: CGSize) -> some View {
        let center = CGFloat(currentIndex) + dragOffset / 280
        let offset = CGFloat(index) - center

        // 视觉曲线：中心=1，向两边衰减
        let distance = abs(offset)
        let scale = max(0.55, 1 - distance * 0.18)
        let rotation = max(-65, min(65, offset * -28))
        let opacity = max(0.35, 1 - distance * 0.25)
        let zIndex = Double(1000 - distance * 100)

        let centerX = size.width / 2
        let xOffset = offset * (bookWidth * 0.55)

        return BookCoverView(book: book, size: .custom(width: bookWidth, height: bookHeight))
            .shadow(color: .black.opacity(0.4 * scale), radius: 20 * scale, y: 8 * scale)
            .scaleEffect(scale)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.4
            )
            .opacity(opacity)
            .offset(x: xOffset)
            .zIndex(zIndex)
            .onTapGesture {
                guard distance < 0.5 else { return }
                onSelect(book)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: currentIndex)
            .animation(.interactiveSpring(), value: dragOffset)
    }

    // MARK: - 底部信息

    private func bookInfo(_ book: Book) -> some View {
        VStack(spacing: 6) {
            Text(book.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: 400)

            HStack(spacing: 10) {
                if let author = book.author {
                    Text(author)
                        .foregroundStyle(palette.textSecondary)
                }
                Text("·")
                    .foregroundStyle(palette.textTertiary)
                Text("\(book.notes.count) 条笔记")
                    .foregroundStyle(palette.textSecondary)
            }
            .font(.system(size: 12))

            // 索引点
            HStack(spacing: 5) {
                ForEach(0..<min(books.count, 12), id: \.self) { i in
                    Circle()
                        .fill(i == currentIndex % min(books.count, 12) ? palette.accent : palette.textTertiary.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
                if books.count > 12 {
                    Text("+\(books.count - 12)")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.textTertiary)
                }
            }
        }
    }

    private func move(by delta: Int) {
        guard !books.isEmpty else { return }
        let newIndex = max(0, min(books.count - 1, currentIndex + delta))
        currentIndex = newIndex
        selectedBookID = newIndex < books.count ? books[newIndex].id : nil
    }
}

// MARK: - 扩展 BookCoverView 支持自定义尺寸

extension BookCoverView {
    enum CoverSize: Equatable {
        case small, medium, large
        case custom(width: CGFloat, height: CGFloat)

        var width: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 48
            case .large: return 82
            case .custom(let w, _): return w
            }
        }

        var height: CGFloat {
            switch self {
            case .small, .medium, .large: return width * 1.36
            case .custom(_, let h): return h
            }
        }

        static func == (lhs: CoverSize, rhs: CoverSize) -> Bool {
            lhs.width == rhs.width && lhs.height == rhs.height
        }
    }
}