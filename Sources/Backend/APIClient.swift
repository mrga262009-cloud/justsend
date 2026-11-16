import Foundation

/// HTTP transport for the JustSend backend. The backend speaks the same
/// `{"result": {...}}` envelope style documented in docs/02-API-RECON.md,
/// which keeps the client wire-compatible with a private-API-shaped service.
final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    struct Configuration: Sendable {
        var baseURL: URL = URL(string: "http://localhost:8787")!
        var tokenProvider: (@Sendable () -> String?)? = nil
        var timeout: TimeInterval = 30
    }

    var config = Configuration()

    func call<T: Decodable>(_ path: String,
                            method: String = "POST",
                            body: [String: Any]? = nil,
                            as type: T.Type = T.self) async throws -> T {
        var request = URLRequest(url: config.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JustSend/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("com.justsend.app", forHTTPHeaderField: "x-ios-bundle-identifier")
        if let token = config.tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.http(0) }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw APIError.decoding(error.localizedDescription) }
    }

    /// Upload media through the resumable-style endpoint exposed by the backend.
    func upload(data: Data, contentType: String, path: String) async throws -> URL {
        var request = URLRequest(url: config.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let (responseData, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        struct UploadReply: Decodable { let url: URL }
        return try JSONDecoder().decode(UploadReply.self, from: responseData).url
    }
}
