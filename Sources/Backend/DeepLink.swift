import Foundation

enum DeepLink {
    static func handle(_ url: URL, session: SessionStore) {
        guard url.scheme == "justsend" else { return }
        switch url.host {
        case "filter":
            NotificationCenter.default.post(name: .openFilter, object: url.path)
        case "friend":
            NotificationCenter.default.post(name: .addFriend, object: url.path)
        default: break
        }
    }
}

extension Notification.Name {
    static let openFilter = Notification.Name("openFilter")
    static let addFriend = Notification.Name("addFriend")
}
