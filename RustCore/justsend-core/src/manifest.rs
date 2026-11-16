//! Parse and merge filter catalogues produced by the crawler.

use crate::error::CoreError;
use crate::filter::FilterDescriptor;

pub fn parse_catalog(json: &str) -> Result<Vec<FilterDescriptor>, CoreError> {
    let v: serde_json::Value = serde_json::from_str(json)?;
    let items = v.as_array()
        .or_else(|| v.get("filters").and_then(|x| x.as_array()))
        .ok_or_else(|| CoreError::Manifest("expected array or {filters:[]}".into()))?;
    let mut out = Vec::with_capacity(items.len());
    for item in items {
        let f: FilterDescriptor = serde_json::from_value(item.clone())?;
        f.validate()?;
        out.push(f);
    }
    Ok(out)
}

/// Dedupe by effect id / descriptor id, preferring newer entries.
pub fn merge(existing: Vec<FilterDescriptor>, incoming: Vec<FilterDescriptor>) -> Vec<FilterDescriptor> {
    use std::collections::HashMap;
    let mut map: HashMap<String, FilterDescriptor> = HashMap::new();
    for f in existing.into_iter().chain(incoming) {
        let key = f.source_effect_id.clone().unwrap_or_else(|| f.id.clone());
        map.insert(key, f);
    }
    let mut v: Vec<_> = map.into_values().collect();
    v.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    v
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parses_and_merges() {
        let j = r#"[{"id":"a","name":"A","source":"bundled","passes":[]}]"#;
        let a = parse_catalog(j).unwrap();
        assert_eq!(a.len(), 1);
        let merged = merge(a.clone(), a);
        assert_eq!(merged.len(), 1);
    }
}
