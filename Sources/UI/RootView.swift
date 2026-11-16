import SwiftUI

enum Tab: Int, CaseIterable {
    case home, history, chat, friends, profile

    var title: String {
        switch self {
        case .home: return "Camera"
        case .history: return "History"
        case .chat: return "Chat"
        case .friends: return "Friends"
        case .profile: return "You"
        }
    }
    var icon: String {
        switch self {
        case .home: return "camera.fill"
        case .history: return "photo.stack.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .friends: return "person.2.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var session: SessionStore
    @State private var tab: Tab = .home
    @State private var showPaywall = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.surface.ignoresSafeArea()
            Group {
                switch tab {
                case .home: CameraHomeView(onPaywall: { showPaywall = true })
                case .history: HistoryView()
                case .chat: ChatView()
                case .friends: FriendsView()
                case .profile: ProfileView(onPaywall: { showPaywall = true })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(tab: $tab)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            UITabBar.appearance().standardAppearance = appearance
        }
    }
}

struct TabBar: View {
    @Binding var tab: Tab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { t in
                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { tab = t } } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.icon)
                            .font(.system(size: 21, weight: tab == t ? .bold : .regular))
                        Text(t.title).font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(tab == t ? Theme.accent : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .accessibilityLabel(t.title)
            }
        }
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(.black.opacity(0.08)), alignment: .top)
    }
}

#Preview {
    RootView()
        .environmentObject(SessionStore())
        .environmentObject(FilterLibrary.shared)
        .environmentObject(BackendContainer.shared)
}
