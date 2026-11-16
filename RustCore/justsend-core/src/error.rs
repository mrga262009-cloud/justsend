use thiserror::Error;

#[derive(Debug, Error)]
pub enum CoreError {
    #[error("invalid manifest: {0}")]
    Manifest(String),
    #[error("unsupported pass type: {0}")]
    UnsupportedPass(String),
    #[error("intensity out of range (0...1): {0}")]
    BadIntensity(f64),
    #[error("http error: {0}")]
    Http(String),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}
