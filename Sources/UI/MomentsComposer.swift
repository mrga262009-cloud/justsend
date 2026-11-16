import SwiftUI
import UIKit

struct MomentsComposer: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    @State private var caption = ""
    @State private var noteType = "standard"
    @State private var selectedFriends: Set<String> = []

    let notes = ["standard", "music", "location", "weather", "time", "streak", "ootd", "good_morning", "goodnight"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(uiImage: image).resizable().scaledToFit().cornerRadius(20).padding()
                    TextField("Add a caption...", text: $caption)
                        .textFieldStyle(.roundedBorder).padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(notes, id: \.self) { n in
                                Button { noteType = n } label: {
                                    Text(n.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.caption).padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(noteType == n ? Theme.accent : Color.gray.opacity(0.15),
                                                    in: Capsule())
                                        .foregroundStyle(noteType == n ? .white : Theme.ink)
                                }
                            }
                        }.padding(.horizontal)
                    }
                    VStack(alignment: .leading) {
                        Text("Send to").font(.headline).padding(.horizontal)
                        ForEach(BackendContainer.sampleFriends) { f in
                            HStack {
                                Avatar(url: f.user?.avatarURL, name: f.user?.displayName ?? "?").frame(width: 36, height: 36)
                                Text(f.user?.displayName ?? "?")
                                Spacer()
                                Image(systemName: selectedFriends.contains(f.uid) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Theme.accent)
                            }
                            .padding(.horizontal).padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedFriends.contains(f.uid) { selectedFriends.remove(f.uid) }
                                else { selectedFriends.insert(f.uid) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { dismiss() }.fontWeight(.bold).foregroundStyle(Theme.accent)
                }
            }
        }
    }
}
