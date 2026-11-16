import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var backend: BackendContainer
    @State private var search = ""
    var body: some View {
        NavigationStack {
            List {
                Section("Requests") {
                    HStack {
                        Avatar(url: nil, name: "?").frame(width: 46, height: 46)
                        VStack(alignment: .leading) { Text("New friend request").font(.headline); Text("From someone you may know").font(.caption).foregroundStyle(Theme.muted) }
                        Spacer()
                        Button("Accept") { }.buttonStyle(.borderedProminent).tint(Theme.accent)
                    }
                }
                Section("Your friends (\(backend.previewFriends.count))") {
                    ForEach(backend.previewFriends) { f in
                        HStack(spacing: 12) {
                            Avatar(url: f.user?.avatarURL, name: f.user?.displayName ?? "?").frame(width: 48, height: 48)
                            VStack(alignment: .leading) {
                                Text(f.user?.displayName ?? "?").font(.headline)
                                Text("\(f.streak) day streak 🔥").font(.caption).foregroundStyle(Theme.accent)
                            }
                            Spacer()
                            Button { } label: { Image(systemName: "camera.fill").foregroundStyle(Theme.accent) }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Friends")
            .searchable(text: $search, prompt: "Search by username")
        }
    }
}
