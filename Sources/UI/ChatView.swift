import SwiftUI

struct ChatView: View {
    @EnvironmentObject var backend: BackendContainer
    var body: some View {
        NavigationStack {
            List {
                ForEach(BackendContainer.sampleFriends) { f in
                    NavigationLink {
                        ConversationView(friend: f)
                    } label: {
                        HStack(spacing: 14) {
                            Avatar(url: f.user?.avatarURL, name: f.user?.displayName ?? "?")
                                .frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(f.user?.displayName ?? "?").font(.headline)
                                Text("Tap to say hi 👋").font(.subheadline).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text("now").font(.caption).foregroundStyle(Theme.muted)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chat")
            .toolbar {
                Button { } label: { Image(systemName: "square.and.pencil") }
            }
        }
    }
}

struct ConversationView: View {
    let friend: Friend
    @State private var text = ""
    @State private var messages: [Message] = []
    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(messages) { m in
                        HStack {
                            if m.senderUID == "me" { Spacer() }
                            Text(m.text ?? "")
                                .padding(12)
                                .background(m.senderUID == "me" ? Theme.accent : Color.white,
                                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .foregroundStyle(m.senderUID == "me" ? .white : Theme.ink)
                            if m.senderUID != "me" { Spacer() }
                        }
                    }
                }.padding()
            }
            HStack {
                TextField("Message...", text: $text)
                    .textFieldStyle(.roundedBorder)
                Button {
                    guard !text.isEmpty else { return }
                    messages.append(Message(id: UUID().uuidString, conversationID: friend.uid,
                                            senderUID: "me", receiverUID: friend.uid, text: text,
                                            clientToken: UUID().uuidString, createdAt: Date()))
                    text = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(Theme.accent)
                }
            }
            .padding()
        }
        .background(Theme.surface)
        .navigationTitle(friend.user?.firstName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}
