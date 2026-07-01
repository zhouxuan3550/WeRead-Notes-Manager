import SwiftUI

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 8
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content.premiumGlassPanel(cornerRadius: cornerRadius, isHighlighted: isHighlighted)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 10, isHighlighted: Bool = false) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}

struct AppBackdrop: View {
    var body: some View {
        PremiumBackground()
    }
}

struct WorkbenchPanel<Content: View>: View {
    let content: Content
    @Environment(\.themePalette) private var palette

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
    }
}
