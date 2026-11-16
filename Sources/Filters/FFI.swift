import Foundation
#if canImport(JustSendFFI)
import JustSendFFI
#endif

/// Thin Swift wrapper around the Rust C ABI. When the static library is not
/// linked (e.g. SwiftUI Preview in a playground), a pure-Swift fallback keeps
/// the UI functional.
enum RustBridge {
    static let available: Bool = {
        #if canImport(JustSendFFI)
        return true
        #else
        return false
        #endif
    }()

    static func version() -> String {
        #if canImport(JustSendFFI)
        let s = js_version()
        defer { js_string_free(s) }
        return String(bytes: Array(UnsafeBufferPointer(start: s.ptr, count: Int(s.len))), encoding: .utf8) ?? "?"
        #else
        return "swift-fallback"
        #endif
    }

    /// Normalise + validate a filter catalogue using Rust.
    static func normalizeCatalog(_ json: String) -> String {
        #if canImport(JustSendFFI)
        let bytes = Array(json.utf8)
        let out = bytes.withUnsafeBufferPointer { buf -> JSString in
            js_normalize_catalog(buf.baseAddress, Int32(buf.count))
        }
        defer { js_string_free(out) }
        return String(bytes: Array(UnsafeBufferPointer(start: out.ptr, count: Int(out.len))), encoding: .utf8) ?? "[]"
        #else
        return json
        #endif
    }

    static func validateCatalog(_ json: String) -> String? {
        #if canImport(JustSendFFI)
        let bytes = Array(json.utf8)
        let out = bytes.withUnsafeBufferPointer { buf -> JSString in
            js_validate_catalog(buf.baseAddress, Int32(buf.count))
        }
        defer { js_string_free(out) }
        let msg = String(bytes: Array(UnsafeBufferPointer(start: out.ptr, count: Int(out.len))), encoding: .utf8) ?? ""
        return msg.hasPrefix("ok:") ? nil : msg
        #else
        return nil
        #endif
    }
}
