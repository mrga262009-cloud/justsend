//! justsend-crawler — polite, checkpointed effect catalogue ingester.
//! Scope: effects you created / effects you are authorised to test. The
//! crawler never mints credentials or bypasses entitlement checks.

use clap::Parser;
use justsend_core::filter::{FilterDescriptor, FilterPass, FilterSource, PassType};
use justsend_core::manifest;
use serde::Deserialize;
use std::collections::HashSet;
use std::path::PathBuf;
use std::time::Duration;

#[derive(Parser, Debug)]
#[command(name = "justsend-crawler", version, about = "Crawl TikTok effect metadata into a JustSend catalogue")]
struct Args {
    /// Source adapter: manual (local JSON seed) or socialcrawl.
    #[arg(long, default_value = "manual")]
    source: String,

    /// Seed effect ids (comma separated).
    #[arg(long)]
    ids: Option<String>,

    /// Optional SocialCrawl API key (prefer env SOCIALCRAWL_API_KEY).
    #[arg(long, env = "SOCIALCRAWL_API_KEY")]
    api_key: Option<String>,

    /// Output catalogue JSON.
    #[arg(long, default_value = "catalog.json")]
    out: PathBuf,

    /// Checkpoint file of already-seen ids.
    #[arg(long, default_value = "crawler.checkpoint")]
    checkpoint: PathBuf,

    /// Requests per second (politeness cap).
    #[arg(long, default_value_t = 1.0)]
    rps: f64,

    /// Max requests this run.
    #[arg(long, default_value_t = 100)]
    budget: u32,
}

#[derive(Debug, Deserialize)]
struct Envelope {
    #[serde(default)]
    data: Vec<EffectRow>,
}

#[derive(Debug, Deserialize)]
struct EffectRow {
    id: String,
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    author: Option<String>,
    #[serde(default)]
    thumbnail: Option<String>,
    #[serde(default)]
    effect_url: Option<String>,
}

fn load_checkpoint(path: &PathBuf) -> HashSet<String> {
    std::fs::read_to_string(path)
        .unwrap_or_default()
        .lines()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(String::from)
        .collect()
}

fn save_checkpoint(path: &PathBuf, seen: &HashSet<String>) -> std::io::Result<()> {
    let mut v: Vec<&str> = seen.iter().map(String::as_str).collect();
    v.sort_unstable();
    std::fs::write(path, v.join("\n"))
}

fn default_passes() -> Vec<FilterPass> {
    vec![
        FilterPass { pass_type: PassType::Beautify, intensity: 0.55, parameters: Default::default() },
        FilterPass { pass_type: PassType::Whiten, intensity: 0.35, parameters: Default::default() },
        FilterPass { pass_type: PassType::Lut, intensity: 1.0, parameters: Default::default() },
    ]
}

fn row_to_filter(row: EffectRow) -> FilterDescriptor {
    FilterDescriptor {
        id: format!("tt-{}", row.id),
        name: row.name.unwrap_or_else(|| format!("Effect {}", row.id)),
        source: FilterSource::Tiktok,
        author: row.author,
        thumbnail: row.thumbnail,
        lut: None,
        passes: default_passes(),
        tags: vec!["tiktok".into(), "beauty".into()],
        effect_url: row.effect_url,
        source_effect_id: Some(row.id),
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).init();
    let args = Args::parse();
    let mut seen = load_checkpoint(&args.checkpoint);
    let mut filters: Vec<FilterDescriptor> = Vec::new();

    let ids: Vec<String> = args.ids.as_deref().unwrap_or("")
        .split(',').map(str::trim).filter(|s| !s.is_empty()).map(String::from).collect();

    match args.source.as_str() {
        "manual" => {
            // Seed mode: take ids that have not been ingested before. This is
            // the offline-safe path: no network, no credentials, fully auditable.
            for id in ids {
                if seen.contains(&id) { continue; }
                if filters.len() >= args.budget as usize { break; }
                seen.insert(id.clone());
                filters.push(row_to_filter(EffectRow {
                    id, name: None, author: None, thumbnail: None, effect_url: None,
                }));
            }
        }
        "socialcrawl" => {
            let key = args.api_key.ok_or("SOCIALCRAWL_API_KEY is required")?;
            let client = reqwest::Client::builder()
                .timeout(Duration::from_secs(30))
                .build()?;
            let delay = Duration::from_secs_f64((1.0 / args.rps.max(0.1)).max(0.1));
            for chunk in ids.chunks(50).take(args.budget as usize) {
                let url = format!("https://www.socialcrawl.dev/v1/tiktok/effects?ids={}", chunk.join(","));
                let resp = client.get(&url).header("x-api-key", &key).send().await?;
                if resp.status() == 429 {
                    tracing::warn!("429 rate limited — stopping run; resume from checkpoint");
                    break;
                }
                if resp.status() == 401 || resp.status() == 403 {
                    tracing::error!("auth failed — stop (do not retry with borrowed credentials)");
                    return Err("upstream auth failed".into());
                }
                if !resp.status().is_success() {
                    tracing::warn!(status = %resp.status(), "upstream error — stopping");
                    break;
                }
                let env: Envelope = resp.json().await?;
                for row in env.data {
                    if seen.contains(&row.id) { continue; }
                    seen.insert(row.id.clone());
                    filters.push(row_to_filter(row));
                }
                tokio::time::sleep(delay).await;
            }
        }
        other => return Err(format!("unknown source {other}").into()),
    }

    // Always validate and normalise before writing.
    filters = manifest::merge(Vec::new(), filters);
    for f in &filters { f.validate()?; }
    let json = serde_json::to_string_pretty(&filters)?;
    std::fs::write(&args.out, &json)?;
    save_checkpoint(&args.checkpoint, &seen)?;
    tracing::info!(count = filters.len(), out = %args.out.display(), "catalogue written");
    Ok(())
}
