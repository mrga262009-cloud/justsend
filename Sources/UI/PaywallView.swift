import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var backend: BackendContainer
    @Environment(\.dismiss) var dismiss
    @State private var selected = "yearly"

    private let products: [(id: String, title: String, price: String, note: String)] = [
        ("js_plus_monthly", "Monthly", "$3.99", "/mo"),
        ("js_plus_yearly", "Yearly", "$23.99", "/yr · save 50%"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.ink, Theme.accent.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    HStack { Spacer(); Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.white.opacity(0.7)) } }
                    Image(systemName: "sparkles").font(.system(size: 56)).foregroundStyle(Theme.gold)
                    Text("JustSend Plus").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.white)
                    Text("Everything you love, turned all the way up.")
                        .foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 14) {
                        Feature(icon: "video.fill", title: "60-second videos", detail: "Capture up to a full minute, not just 15s.")
                        Feature(icon: "eye.fill", title: "See who viewed", detail: "Know who stopped by your moments.")
                        Feature(icon: "sparkles", title: "Unlimited filters", detail: "Every TikTok effect and beauty look.")
                        Feature(icon: "square.grid.2x2.fill", title: "Photobooth HD", detail: "Unlimited 4-frame strips, no watermark.")
                        Feature(icon: "bolt.slash.fill", title: "No ads", detail: "A clean, distraction-free History.")
                    }
                    .padding(20).background(.ultraThinMaterial,
                                            in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    ForEach(products, id: \.id) { p in
                        Button { selected = p.id } label: {
                            HStack {
                                Image(systemName: selected == p.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Theme.gold)
                                Text(p.title).foregroundStyle(.white)
                                Spacer()
                                Text(p.price).foregroundStyle(.white).fontWeight(.semibold)
                                Text(p.note).font(.caption).foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(16).background(.black.opacity(0.3),
                                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    Button {
                        backend.isPlus = true
                        dismiss()
                    } label: {
                        Text("Start free trial").primaryButton()
                    }
                    Text("Cancel anytime. Payment charged to your Apple ID.")
                        .font(.caption2).foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
}

struct Feature: View {
    let icon: String; let title: String; let detail: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.gold).frame(width: 28)
            VStack(alignment: .leading) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(detail).font(.caption).foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
