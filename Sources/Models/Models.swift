import Foundation
import SwiftUI

// MARK: - Domain models (wire-compatible with the Locket private API shape)

struct User: Identifiable, Codable, Hashable, Sendable {
    var uid: String
    var firstName: String
    var lastName: String
    var username: String?
    var avatarURL: URL?
    var badge: String?          // "locket_gold" equivalent -> "justsend_plus"
    var isTemp: Bool = false

    var displayName: String { [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ") }

    enum CodingKeys: String, CodingKey {
        case uid, firstName = "first_name", lastName = "last_name", username
        case avatarURL = "profile_picture_url", badge
        case isTemp = "temp"
    }
    var id: String { uid }

    static let preview = User(uid: "u1", firstName: "Minh", lastName: "Nguyen",
                              username: "minh", avatarURL: nil, badge: "justsend_plus")
}

struct Friend: Identifiable, Codable, Hashable, Sendable {
    var uid: String
    var user: User?
    var createdAt: Date?
    var sharedHistoryOn: Date?
    var streak: Int = 0
    var id: String { uid }
}

enum MomentKind: String, Codable, Sendable { case image, video, livePhoto, text }

struct Moment: Identifiable, Codable, Hashable, Sendable {
    var canonicalUID: String
    var ownerUID: String
    var date: Date
    var kind: MomentKind = .image
    var thumbnailURL: URL?
    var mediaURL: URL?
    var localMediaPath: String?
    var caption: String?
    var noteType: String?
    var durationSeconds: Double?
    var isPrivate: Bool = false
    var recipients: [String] = []
    var reactions: [Reaction] = []
    var viewCount: Int = 0
    var md5: String?

    enum CodingKeys: String, CodingKey {
        case canonicalUID = "canonical_uid", ownerUID = "user", date, kind, thumbnailURL = "thumbnail_url"
        case mediaURL = "image_url", localMediaPath, caption, noteType = "note_type"
        case durationSeconds, isPrivate, recipients, reactions, viewCount = "views", md5
    }
    var id: String { canonicalUID }
}

struct Reaction: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var uid: String
    var emoji: String
    var createdAt: Date
}

struct Message: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var conversationID: String
    var senderUID: String
    var receiverUID: String
    var text: String?
    var momentUID: String?
    var clientToken: String
    var createdAt: Date
    var reactions: [String: String] = [:]   // emoji -> uid
    var isRead: Bool = false
    var isUnsent: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, conversationID = "conversation_uid", senderUID = "sender"
        case receiverUID = "receiver", text, momentUID = "moment_uid"
        case clientToken = "client_token", createdAt = "created_at"
        case reactions, isRead, isUnsent
    }
}

struct Conversation: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var peerUID: String
    var lastMessage: String?
    var lastActivityAt: Date
    var unreadCount: Int = 0
    var peerLastReadAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, peerUID = "peer", lastMessage = "snippet"
        case lastActivityAt = "last_activity", unreadCount = "unread", peerLastReadAt
    }
}

enum FriendRequestState: String, Codable, Sendable {
    case none, incoming, outgoing, friends, blocked
}

// MARK: - Filters

enum FilterSource: String, Codable, Sendable { case bundled, local, tiktok, community }

struct FilterDescriptor: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var source: FilterSource
    var authorName: String?
    var thumbnailURL: URL?
    var localThumbnailPath: String?
    var lutPath: String?
    var effectBundlePath: String?      // downloaded .zip/.bundle (Effect House-style)
    var intensity: Double = 1.0
    var tags: [String] = []
    var isFavorite: Bool = false
    var createdAt: Date = Date()

    init(id: String, name: String, source: FilterSource, authorName: String? = nil,
         thumbnailURL: URL? = nil, localThumbnailPath: String? = nil, lutPath: String? = nil,
         effectBundlePath: String? = nil, intensity: Double = 1.0, tags: [String] = [],
         isFavorite: Bool = false, createdAt: Date = Date()) {
        self.id = id; self.name = name; self.source = source; self.authorName = authorName
        self.thumbnailURL = thumbnailURL; self.localThumbnailPath = localThumbnailPath
        self.lutPath = lutPath; self.effectBundlePath = effectBundlePath
        self.intensity = intensity; self.tags = tags; self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, source
        case authorName = "author"
        case thumbnailURL = "thumbnail"
        case localThumbnailPath
        case lutPath = "lut"
        case effectBundlePath = "effect_url"
        case intensity, tags, isFavorite, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        source = try c.decode(FilterSource.self, forKey: .source)
        authorName = try c.decodeIfPresent(String.self, forKey: .authorName)
        thumbnailURL = try c.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        localThumbnailPath = try c.decodeIfPresent(String.self, forKey: .localThumbnailPath)
        lutPath = try c.decodeIfPresent(String.self, forKey: .lutPath)
        effectBundlePath = try c.decodeIfPresent(String.self, forKey: .effectBundlePath)
        intensity = try c.decodeIfPresent(Double.self, forKey: .intensity) ?? 1.0
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

struct FilterManifest: Codable, Sendable {
    var id: String
    var name: String
    var author: String?
    var version: String = "1"
    var thumbnail: String?
    var lut: String?
    var passes: [FilterPass] = []
    var parameters: [String: Double] = [:]
}

struct FilterPass: Codable, Sendable {
    var type: PassType
    var intensity: Double = 1.0
    var ciFilterName: String?
    var parameters: [String: Double] = [:]

    enum PassType: String, Codable, Sendable {
        case lut, beautify, smooth, whiten, contour, blur, vignette, grain, overlay, ar
    }
}

// MARK: - Rollcall / Journal / Widget

struct RollcallPost: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var authorUID: String
    var weekOfYear: Int
    var year: Int
    var imageURLs: [URL]
    var caption: String?
    var reactions: [Reaction] = []
    var createdAt: Date
}

struct JournalDay: Identifiable, Codable, Hashable, Sendable {
    var id: String { dateKey }
    var dateKey: String
    var moments: [Moment]
    var holiday: String?
}

struct WidgetSnapshot: Codable, Sendable {
    var images: [URL]
    var friendUIDs: [String]
    var streak: Int
    var updatedAt: Date
}

// MARK: - API envelope

struct APIEnvelope<T: Decodable>: Decodable {
    let result: Result
    struct Result: Decodable {
        let data: T?
        let errors: [String]?
        let status: Int?
        let syncToken: String?
        let missedMomentsCount: Int?
        enum CodingKeys: String, CodingKey {
            case data, errors, status
            case syncToken = "sync_token"
            case missedMomentsCount = "missed_moments_count"
        }
    }
}

// MARK: - Error

enum APIError: LocalizedError {
    case notAuthenticated
    case body(String)
    case http(Int)
    case decoding(String)
    case fileTooLarge(limit: Int)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Please sign in."
        case .body(let s): return s
        case .http(let c): return "Request failed (\(c))."
        case .decoding(let s): return "Could not parse response: \(s)"
        case .fileTooLarge(let l): return "File too large (limit \(l / 1_000_000) MB)."
        case .cancelled: return "Cancelled."
        }
    }
}
