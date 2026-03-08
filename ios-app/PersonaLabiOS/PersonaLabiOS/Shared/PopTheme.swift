import SwiftUI

enum PopTheme {
    static let backgroundTop = Color(red: 1.00, green: 0.96, blue: 0.78)
    static let backgroundBottom = Color(red: 0.79, green: 0.94, blue: 1.00)

    static let accent = Color(red: 0.98, green: 0.45, blue: 0.38)
    static let accentAlt = Color(red: 0.13, green: 0.70, blue: 0.84)

    static let cardFill = Color.white.opacity(0.87)
    static let textPrimary = Color(red: 0.13, green: 0.15, blue: 0.24)
}

struct PopBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PopTheme.backgroundTop, PopTheme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(PopTheme.accent.opacity(0.22))
                .frame(width: 280, height: 280)
                .offset(x: -130, y: -260)

            Circle()
                .fill(PopTheme.accentAlt.opacity(0.20))
                .frame(width: 300, height: 300)
                .offset(x: 160, y: 280)

            Circle()
                .fill(Color.white.opacity(0.30))
                .frame(width: 170, height: 170)
                .offset(x: 150, y: -220)
        }
    }
}

struct PopCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PopTheme.cardFill)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            )
    }
}

extension View {
    func popCard(cornerRadius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        modifier(PopCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
