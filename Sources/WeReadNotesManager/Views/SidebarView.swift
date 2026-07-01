import SwiftUI

/// 侧栏入口 - 使用 LiquidGlassSidebar 提供 macOS 26 风格液态玻璃
/// 保留同名 `SidebarView` 以兼容 MainView 调用
struct SidebarView: View {
    var body: some View {
        LiquidGlassSidebar()
    }
}