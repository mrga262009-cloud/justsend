import Foundation

/// Cầu nối Swift ↔ Rust (C ABI). Các hàm C được import vào Swift qua
/// `SWIFT_OBJC_BRIDGING_HEADER`, nên chỉ dùng khi cờ `JUSTSEND_NATIVE` được bật
/// (tức là `libjustsend.a` đã được link trong bản build CI).
enum RustBridge {
    static func version() -> String {
        #if JUSTSEND_NATIVE
        let s = js_version()
        defer { js_string_free(s) }
        return swiftString(s)
        #else
        return "swift-fallback"
        #endif
    }

    /// Chuẩn hoá + kiểm tra catalogue bằng Rust.
    static func normalizeCatalog(_ json: String) -> String {
        #if JUSTSEND_NATIVE
        return withCBytes(json) { ptr, len in takeString(js_normalize_catalog(ptr, len)) }
        #else
        return json
        #endif
    }

    static func validateCatalog(_ json: String) -> String? {
        #if JUSTSEND_NATIVE
        let msg = withCBytes(json) { ptr, len in takeString(js_validate_catalog(ptr, len)) }
        return msg.hasPrefix("ok:") ? nil : msg
        #else
        return nil
        #endif
    }

    static func ciChain(_ json: String) -> [String] {
        #if JUSTSEND_NATIVE
        let raw = withCBytes(json) { ptr, len in takeString(js_ci_chain(ptr, len)) }
        return raw.isEmpty ? [] : raw.split(separator: ",").map(String.init)
        #else
        return []
        #endif
    }

    // MARK: - Helpers

    #if JUSTSEND_NATIVE
    private static func takeString(_ s: JSString) -> String {
        defer { js_string_free(s) }
        return swiftString(s)
    }
    #endif

    private static func swiftString(_ s: JSString) -> String {
        guard let ptr = s.ptr, s.len > 0 else { return "" }
        let raw = UnsafeRawBufferPointer(start: ptr, count: Int(s.len))
        return String(decoding: raw.bindMemory(to: UInt8.self), as: UTF8.self)
    }

    /// Truyền chuỗi JSON vào Rust dưới dạng `const char *` + độ dài,
    /// loại bỏ ký tự NUL kết thúc để tránh lỗi "trailing characters".
    private static func withCBytes<R>(_ json: String,
                                      _ body: (UnsafePointer<CChar>?, Int32) -> R) -> R {
        let bytes = Array(json.utf8CString)   // [CChar], có NUL cuối
        let len = Int32(max(bytes.count - 1, 0))
        return bytes.withUnsafeBufferPointer { buf in
            body(buf.baseAddress, len)
        }
    }
}
