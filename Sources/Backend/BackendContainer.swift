import Foundation
import SwiftUI

@MainActor
final class BackendContainer: ObservableObject {
    static let shared = BackendContainer()

    @Published var friends: [Friend] = []
    @Published var moments: [Moment] = []
    @Published var conversations: [Conversation] = []
    @Published var isPlus: Bool = UserDefaults.standard.bool(forKey: "js.isPlus") {
        didSet { UserDefaults.standard.set(isPlus, forKey: "js.isPlus") }
    }

    let api = APIClient.shared

    var previewFriends: [Friend] {
        friends.isEmpty ? Self.sampleFriends : friends
    }

    func refresh() async {
        // When configured with a real backend, this calls the Locket-shaped
        // endpoints described in docs/02-API-RECON.md. Local-first by default.
        let data = try? await api.call("getLatestMomentV2", body: ["data": ["should_count_missed_moments": true]],
                                       as: APIEnvelope<[Moment]>.self)
        if let items = data?.result.data { moments = items }
    }

    static let sampleFriends: [Friend] = [
        Friend(uid: "f1", user: User(uid: "f1", firstName: "Lan", lastName: "Tran", badge: "justsend_plus"), streak: 42),
        Friend(uid: "f2", user: User(uid: "f2", firstName: "Khoa", lastName: "Nguyen"), streak: 12),
        Friend(uid: "f3", user: User(uid: "f3", firstName: "Mai", lastName: "Pham"), streak: 7),
        Friend(uid: "f4", user: User(uid: "f4", firstName: "Tuan", lastName: "Le"), streak: 3),
        Friend(uid: "f5", user: User(uid: "f5", firstName: "Anh", lastName: "Vo"), streak: 91),
    ]

    static let sampleMoments: [Moment] = [
        Moment(canonicalUID: "m1", ownerUID: "f1", date: Date().addingTimeInterval(-3600),
               thumbnailURL: nil, caption: "Golden hour ✨", noteType: "standard", viewCount: 4,
               reactions: [Reaction(id: "r1", uid: "f2", emoji: "❤️", createdAt: Date())]),
        Moment(canonicalUID: "m2", ownerUID: "f3", date: Date().addingTimeInterval(-7200),
               caption: "Weekend vibes", noteType: "standard", kind: .video, durationSeconds: 28, viewCount: 9),
    ]
}
