import SwiftUI

// MARK: - 统一空状态视图
//
// 用法：
//   EmptyStateView(
//       title: "还没有收藏",
//       subtitle: "在笔记详情页点击星标即可收藏",
//       systemImage: "star",
//       action: EmptyStateView.Action(title: "去全部笔记", systemImage: "note.text") { ... }
//   )

struct EmptyStateView: View {
    @Environment(\.themePalette) private var palette

    let title: String
    var subtitle: String? = nil
    var systemImage: String = "doc.text"
    var action: Action? = nil

    struct Action {
        let title: String
        let systemImage: String
        let handler: () -> Void

        init(title: String, systemImage: String, handler: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.handler = handler
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(palette.accentSoft)
                    .frame(width: 80, height: 80)

                Image(systemName: systemImage)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
            }

            if let action {
                Button(action: action.handler) {
                    Label(action.title, systemImage: action.systemImage)
                }
                .flatActionButton(.accent, height: 34)
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }
}

// MARK: - 旧占位兼容（保留空文件占位，避免其他 import 失败）
