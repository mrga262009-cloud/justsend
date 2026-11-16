import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var backend: BackendContainer
    var onPaywall: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        Avatar(url: nil, name: session.displayName).frame(width: 96, height: 96)
                            .overlay(Circle().stroke(backend.isPlus ? Theme.gold : Theme.accent, lineWidth: 3))
                        Text(session.displayName).font(.system(size: 24, weight: .black, design: .rounded))
                        if backend.isPlus {
                            Label("JustSend Plus", systemImage: "sparkles").foregroundStyle(Theme.gold)
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("@\(session.username.isEmpty ? "you" : session.username)")
                            .foregroundStyle(Theme.muted).font(.subheadline)
                    }
                    .padding(.top, 12)

                    HStack(spacing: 12) {
                        Stat(value: "\(session.streak)", label: "day streak")
                        Stat(value: "127", label: "moments")
                        Stat(value: "\(backend.previewFriends.count)", label: "friends")
                    }
                    .padding(.horizontal, 20)

                    if !backend.isPlus {
                        Button(action: onPaywall) {
                            HStack {
                                Image(systemName: "sparkles")
                                VStack(alignment: .leading) {
                                    Text("Unlock JustSend Plus").font(.headline)
                                    Text("60s video, no ads, moment views & more").font(.caption)
                                }
                                Spacer(); Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(.white).padding(16)
                            .background(LinearGradient(colors: [Theme.gold.opacity(0.85), Theme.accent.opacity(0.8)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .padding(.horizontal, 20)
                    }

                    List {
                        NavigationLink("Edit profile") { Text("Edit profile") }
                        NavigationLink("App icon") { Text("Alternate icons") }
                        NavigationLink("Camera themes") { Text("Camera themes") }
                        NavigationLink("Privacy & safety") { Text("Privacy & safety") }
                        NavigationLink("Data export") { Text("Data export") }
                        NavigationLink("Help center") { Text("Help") }
                        Button("Sign out", role: .destructive) { session.signOut() }
                    }
                    .frame(height: 330)
                    .scrollContentBackground(.hidden)
                }
                .padding(.bottom, 100)
            }
            .background(Theme.surface)
        }
    }
}

struct Stat: View {
    let value: String; let label: String
    var body: some View {
        VStack {
            Text(value).font(.system(size: 22, weight: .black, design: .rounded))
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }.frame(maxWidth: .infinity).padding(.vertical, 14).glassCard()
    }
}
