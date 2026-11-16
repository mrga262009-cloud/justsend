//! justsend-core — platform-independent filter/effect model + RATA client.
//! Consumed by the Swift app through the `justsend-ffi` C ABI and by the
//! `justsend-crawler` binary. No iOS frameworks here.

pub mod filter;
pub mod manifest;
pub mod rata;
pub mod error;

pub use error::CoreError;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");
