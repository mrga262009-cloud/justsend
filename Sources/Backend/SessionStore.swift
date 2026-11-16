import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    @AppStorage("js.uid") var uid: String = ""
    @AppStorage("js.displayName") var displayName: String = "Guest"
    @AppStorage("js.username") var username: String = ""
    @AppStorage("js.token") var idToken: String = ""
    @AppStorage("js.refresh") var refreshToken: String = ""
    @AppStorage("js.isPlus") var isPlus: Bool = false
    @AppStorage("js.onboarded") var onboarded: Bool = false
    @AppStorage("js.streak") var streak: Int = 0

    var currentUser: User {
        User(uid: uid.isEmpty ? "me" : uid,
             firstName: displayName,
             lastName: "",
             username: username.isEmpty ? nil : username,
             badge: isPlus ? "justsend_plus" : nil)
    }

    func signIn(email: String, password: String) async throws {
        // Local-first demo auth. A configured HTTP backend replaces this with
        // POST /identitytoolkit/.../verifyPassword (see docs/02-API-RECON.md).
        try await Task.sleep(nanoseconds: 350_000_000)
        uid = "me-\(abs(email.hashValue))"
        displayName = email.split(separator: "@").first.map(String.init) ?? "Friend"
        isPlus = UserDefaults.standard.bool(forKey: "js.isPlus")
        onboarded = true
    }

    func signOut() {
        uid = ""; idToken = ""; refreshToken = ""; onboarded = false
    }
}
