//! C ABI for Swift. All strings crossing the boundary are UTF-8, owned by
//! Rust until `js_string_free` is called from Swift.

use justsend_core::{filter::FilterDescriptor, manifest};
use std::ffi::{c_char, c_int, CString};

/// Owned UTF-8 string returned to Swift.
#[repr(C)]
pub struct JSString {
    pub ptr: *mut c_char,
    pub len: c_int,
}

unsafe fn to_string(s: String) -> JSString {
    let len = s.len() as c_int;
    let ptr = CString::new(s).unwrap_or_else(|_| CString::new("").unwrap()).into_raw();
    JSString { ptr, len }
}

/// # Safety
/// `s` must come from this library and be freed exactly once.
#[no_mangle]
pub unsafe extern "C" fn js_string_free(s: JSString) {
    if !s.ptr.is_null() {
        drop(CString::from_raw(s.ptr));
    }
}

/// Validate a filter catalogue JSON blob. Returns NULL on success,
/// otherwise an owned error message.
///
/// # Safety
/// `ptr` must point to `len` readable bytes of UTF-8 JSON.
#[no_mangle]
pub unsafe extern "C" fn js_validate_catalog(ptr: *const c_char, len: c_int) -> JSString {
    if ptr.is_null() || len <= 0 { return to_string("empty input".into()); }
    let bytes = std::slice::from_raw_parts(ptr as *const u8, len as usize);
    let json = match std::str::from_utf8(bytes) {
        Ok(s) => s,
        Err(e) => return to_string(format!("invalid utf8: {e}")),
    };
    match manifest::parse_catalog(json) {
        Ok(list) => to_string(format!("ok:{}", list.len())),
        Err(e) => to_string(e.to_string()),
    }
}

/// Parse a catalogue and return a normalised JSON array (sorted, deduped)
/// for Swift to decode into `[FilterDescriptor]`.
///
/// # Safety
/// `ptr` must point to `len` readable bytes.
#[no_mangle]
pub unsafe extern "C" fn js_normalize_catalog(ptr: *const c_char, len: c_int) -> JSString {
    if ptr.is_null() || len <= 0 { return to_string("[]".into()); }
    let bytes = std::slice::from_raw_parts(ptr as *const u8, len as usize);
    match std::str::from_utf8(bytes) {
        Ok(json) => match manifest::parse_catalog(json) {
            Ok(list) => {
                let merged = manifest::merge(Vec::<FilterDescriptor>::new(), list);
                to_string(serde_json::to_string(&merged).unwrap_or_else(|_| "[]".into()))
            }
            Err(_) => to_string("[]".into()),
        },
        Err(_) => to_string("[]".into()),
    }
}

/// Return the ordered Core Image filter chain for one descriptor as a
/// comma-separated list. Swift splits on ","
///
/// # Safety
/// `ptr` must point to `len` readable bytes.
#[no_mangle]
pub unsafe extern "C" fn js_ci_chain(ptr: *const c_char, len: c_int) -> JSString {
    if ptr.is_null() || len <= 0 { return to_string(String::new()); }
    let bytes = std::slice::from_raw_parts(ptr as *const u8, len as usize);
    let out = std::str::from_utf8(bytes)
        .ok()
        .and_then(|s| serde_json::from_str::<FilterDescriptor>(s).ok())
        .map(|f| f.ci_chain().join(","))
        .unwrap_or_default();
    to_string(out)
}

/// # Safety
/// `ptr` must point to a valid NUL-terminated C string.
#[no_mangle]
pub unsafe extern "C" fn js_version() -> JSString {
    to_string(justsend_core::VERSION.into())
}
