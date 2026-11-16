import SwiftUI

enum Theme {
    static let accent = Color(hex: "FF5A79")       // Locket-ish coral/pink
    static let gold = Color(hex: "F7C86B")
    static let ink = Color(hex: "1A1520")
    static let muted = Color(hex: "8E8798")
    static let surface = Color(hex: "F7F5F8")
    static let card = Color.white

    static let corner: CGFloat = 22
    static let shadow = Color.black.opacity(0.08)
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        let r = Double((n >> 16) & 0xFF) / 255
        let g = Double((n >> 8) & 0xFF) / 255
        let b = Double(n & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

struct PrimaryButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.75)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.25), radius: 12, y: 6)
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 0.5))
    }
}

extension View {
    func primaryButton() -> some View { modifier(PrimaryButton()) }
    func glassCard() -> some View { modifier(GlassCard()) }
}
