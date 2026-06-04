use std::fs;
use std::path::Path;

use napi_derive::napi;

use crate::errors::BrewweryError;
use crate::runner::run_brew_output;

#[napi(object)]
pub struct BrewfileEntry {
    pub kind: String,
    pub name: String,
    pub raw: String,
}

#[napi(object)]
#[allow(non_snake_case)]
pub struct BrewfileReadResult {
    pub path: String,
    pub entries: Vec<BrewfileEntry>,
    pub rawContent: String,
}

#[napi(object)]
#[allow(non_snake_case)]
pub struct BrewfileExportResult {
    pub path: Option<String>,
    pub entries: Vec<BrewfileEntry>,
    pub rawContent: String,
}

#[napi]
pub fn export_brewfile() -> napi::Result<BrewfileExportResult> {
    let path = std::env::temp_dir().join(format!("brewwery-Brewfile-{}", std::process::id()));
    let file_arg = format!("--file={}", path.to_string_lossy());
    let args = ["bundle", "dump", "--force", file_arg.as_str()];

    run_brew_output(&args).map_err(|error| napi::Error::from_reason(error.to_string()))?;

    let raw_content = fs::read_to_string(&path).map_err(|error| napi::Error::from_reason(error.to_string()))?;
    let entries = parse_brewfile_entries(&raw_content);

    Ok(BrewfileExportResult {
        path: Some(path.to_string_lossy().to_string()),
        entries,
        rawContent: raw_content,
    })
}

#[napi]
pub fn read_brewfile(path: String) -> napi::Result<BrewfileReadResult> {
    validate_brewfile_path(&path)?;

    let raw_content = fs::read_to_string(&path).map_err(|error| napi::Error::from_reason(error.to_string()))?;
    if raw_content.len() > 1_000_000 {
        return Err(napi::Error::from_reason(
            BrewweryError::InvalidFilePath("Brewfile is too large.".to_string()).to_string(),
        ));
    }

    let entries = parse_brewfile_entries(&raw_content);

    Ok(BrewfileReadResult {
        path,
        entries,
        rawContent: raw_content,
    })
}

fn validate_brewfile_path(path: &str) -> napi::Result<()> {
    let candidate = Path::new(path);
    let file_name = candidate
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();

    if candidate.is_absolute()
        && candidate.is_file()
        && !path.contains('\0')
        && (file_name == "brewfile" || file_name.ends_with(".brewfile"))
    {
        return Ok(());
    }

    Err(napi::Error::from_reason(
        BrewweryError::InvalidFilePath(path.to_string()).to_string(),
    ))
}

fn parse_brewfile_entries(content: &str) -> Vec<BrewfileEntry> {
    content
        .lines()
        .filter_map(parse_brewfile_entry)
        .collect::<Vec<_>>()
}

fn parse_brewfile_entry(line: &str) -> Option<BrewfileEntry> {
    let trimmed = line.trim();
    if trimmed.is_empty() || trimmed.starts_with('#') {
        return None;
    }

    let kind = trimmed.split_whitespace().next().unwrap_or("unknown");
    let normalized_kind = match kind {
        "brew" | "cask" | "tap" | "mas" => kind,
        "service" => "service",
        _ => "unknown",
    };
    let name = extract_quoted_name(trimmed).unwrap_or_else(|| trimmed.to_string());

    Some(BrewfileEntry {
        kind: normalized_kind.to_string(),
        name,
        raw: trimmed.to_string(),
    })
}

fn extract_quoted_name(line: &str) -> Option<String> {
    let start = line.find('"')?;
    let rest = &line[start + 1..];
    let end = rest.find('"')?;
    Some(rest[..end].to_string())
}
