//! Minimal RATA contract reader/validator used by the crawler.
//! Enforces the four required rules: version, target.name, an origin, and
//! at least one endpoint with a stable id.

use crate::error::CoreError;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Contract {
    pub version: u32,
    pub target: Target,
    pub endpoints: Vec<Endpoint>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Target {
    pub name: String,
    #[serde(default)]
    pub base_url: Option<String>,
    #[serde(default)]
    pub servers: Vec<Server>,
    #[serde(default)]
    pub limits: Option<Limits>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Server {
    pub id: String,
    pub url: String,
    #[serde(default, rename = "transport")]
    pub transport: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Limits {
    #[serde(default)]
    pub rps: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Endpoint {
    pub id: String,
    #[serde(default)]
    pub server: Option<String>,
    #[serde(default)]
    pub method: Option<String>,
    #[serde(default)]
    pub path: Option<String>,
    #[serde(default)]
    pub confidence: Option<String>,
    #[serde(default, rename = "x-effect-source")]
    pub effect_source: Option<String>,
}

impl Contract {
    pub fn from_yamlish_json(json: &str) -> Result<Self, CoreError> {
        let c: Contract = serde_json::from_str(json)?;
        c.validate()?;
        Ok(c)
    }

    pub fn validate(&self) -> Result<(), CoreError> {
        if self.version == 0 { return Err(CoreError::Manifest("version must be > 0".into())); }
        if self.target.name.trim().is_empty() { return Err(CoreError::Manifest("target.name required".into())); }
        if self.target.base_url.is_none() && self.target.servers.is_empty() {
            return Err(CoreError::Manifest("target.base_url or servers[] required".into()));
        }
        if self.endpoints.is_empty() { return Err(CoreError::Manifest("at least one endpoint required".into())); }
        for e in &self.endpoints {
            if e.id.trim().is_empty() { return Err(CoreError::Manifest("endpoint id required".into())); }
            if e.path.is_none() { return Err(CoreError::Manifest(format!("{}: path required", e.id))); }
        }
        Ok(())
    }

    pub fn resolve_url(&self, endpoint: &Endpoint) -> Result<String, CoreError> {
        if let Some(sid) = &endpoint.server {
            let s = self.target.servers.iter().find(|s| &s.id == sid)
                .ok_or_else(|| CoreError::Manifest(format!("unknown server {sid}")))?;
            return Ok(format!("{}{}", s.url.trim_end_matches('/'), endpoint.path.as_deref().unwrap_or("")));
        }
        let base = self.target.base_url.as_ref()
            .ok_or_else(|| CoreError::Manifest("no base_url".into()))?;
        Ok(format!("{}{}", base.trim_end_matches('/'), endpoint.path.as_deref().unwrap_or("")))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn validates_contract() {
        let j = r#"{"version":1,"target":{"name":"tt","servers":[{"id":"api","url":"https://api.tiktokv.com"}]},
          "endpoints":[{"id":"effect_search","server":"api","path":"/aweme/v1/search/effect/"}]}"#;
        let c = Contract::from_yamlish_json(j).unwrap();
        assert_eq!(c.resolve_url(&c.endpoints[0]).unwrap(),
                   "https://api.tiktokv.com/aweme/v1/search/effect/");
    }
}
