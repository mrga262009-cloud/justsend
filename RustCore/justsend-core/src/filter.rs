//! Filter model shared by Swift and the Rust crawler.
//! A "look" is an ordered graph of passes. Each pass maps to either a
//! Core Image filter on the Swift side or a GPU shader on the Rust side.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FilterSource {
    Bundled,
    Local,
    Tiktok,
    Community,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PassType {
    Lut,
    Beautify,
    Smooth,
    Whiten,
    Contour,
    Blur,
    Vignette,
    Grain,
    Overlay,
    Ar,
}

impl PassType {
    /// Core Image filter name used by the Swift renderer.
    pub fn ci_name(self) -> &'static str {
        match self {
            Self::Lut => "CIColorCube",
            Self::Beautify => "CIBilateralFilter",
            Self::Smooth => "CIGaussianBlur",
            Self::Whiten => "CIColorControls",
            Self::Contour => "CIUnsharpMask",
            Self::Blur => "CIGaussianBlur",
            Self::Vignette => "CIVignette",
            Self::Grain => "CINoiseReduction",
            Self::Overlay => "CISourceOverCompositing",
            Self::Ar => "CIDisplacementDistortion",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FilterPass {
    pub pass_type: PassType,
    #[serde(default = "one")]
    pub intensity: f64,
    #[serde(default)]
    pub parameters: std::collections::BTreeMap<String, f64>,
}

fn one() -> f64 { 1.0 }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FilterDescriptor {
    pub id: String,
    pub name: String,
    pub source: FilterSource,
    #[serde(default)]
    pub author: Option<String>,
    #[serde(default)]
    pub thumbnail: Option<String>,
    #[serde(default)]
    pub lut: Option<String>,
    #[serde(default)]
    pub passes: Vec<FilterPass>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub effect_url: Option<String>,
    #[serde(default)]
    pub source_effect_id: Option<String>,
}

impl FilterDescriptor {
    pub fn validate(&self) -> Result<(), crate::CoreError> {
        if self.id.trim().is_empty() {
            return Err(crate::CoreError::Manifest("empty id".into()));
        }
        if self.name.trim().is_empty() {
            return Err(crate::CoreError::Manifest("empty name".into()));
        }
        for pass in &self.passes {
            if !(0.0..=1.0).contains(&pass.intensity) {
                return Err(crate::CoreError::BadIntensity(pass.intensity));
            }
        }
        Ok(())
    }

    /// Ordered CI filter names for the Swift renderer (LUT must come first).
    pub fn ci_chain(&self) -> Vec<&'static str> {
        let mut out: Vec<&'static str> = self.passes.iter().map(|p| p.pass_type.ci_name()).collect();
        out.sort_by_key(|n| if *n == "CIColorCube" { 0 } else { 1 });
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_and_orders() {
        let f = FilterDescriptor {
            id: "glow".into(), name: "Glow".into(), source: FilterSource::Tiktok,
            author: None, thumbnail: None, lut: Some("lut.png".into()),
            passes: vec![FilterPass { pass_type: PassType::Vignette, intensity: 0.4,
                                      parameters: Default::default() },
                         FilterPass { pass_type: PassType::Lut, intensity: 1.0,
                                      parameters: Default::default() }],
            tags: vec![], effect_url: None, source_effect_id: None,
        };
        f.validate().unwrap();
        assert_eq!(f.ci_chain()[0], "CIColorCube");
    }
}
