use std::path::Path;
use std::process::Command;

use napi_derive::napi;

use crate::runner::run_brew;

const BREW_PATHS: [&str; 2] = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"];

#[napi(object)]
#[allow(non_snake_case)]
pub struct IpcError {
    pub code: String,
    pub message: String,
    pub raw: Option<String>,
}

#[napi(object)]
#[allow(non_snake_case)]
pub struct BrewDetectionResult {
    pub found: bool,
    pub path: Option<String>,
    pub checkedPaths: Vec<String>,
    pub error: Option<IpcError>,
}

#[napi(object)]
pub struct BrewInfo {
    pub version: String,
    pub prefix: String,
    pub architecture: String,
    pub path: String,
}

#[napi]
pub fn detect_homebrew() -> BrewDetectionResult {
    let checked_paths = checked_paths();
    let path = explicit_brew_path().or_else(path_brew_path);
    let found = path.is_some();

    BrewDetectionResult {
        found,
        path,
        checkedPaths: checked_paths,
        error: if found {
            None
        } else {
            Some(IpcError {
                code: "HOMEBREW_NOT_FOUND".to_string(),
                message: "Homebrew was not found in /opt/homebrew, /usr/local, or PATH.".to_string(),
                raw: None,
            })
        },
    }
}

#[napi]
pub fn get_brew_info() -> BrewInfo {
    let detection = detect_homebrew();
    let path = detection.path.unwrap_or_else(|| "unknown".to_string());
    let config = run_brew(&["config"]).ok();
    let config_pairs = config.as_deref().map(parse_brew_config).unwrap_or_default();
    let version_output = run_brew(&["--version"]).ok();

    BrewInfo {
        version: config_value(&config_pairs, "HOMEBREW_VERSION")
            .or_else(|| version_output.and_then(|value| value.lines().next().map(str::to_string)))
            .unwrap_or_else(|| "unknown".to_string()),
        prefix: config_value(&config_pairs, "HOMEBREW_PREFIX").unwrap_or_else(|| "unknown".to_string()),
        architecture: config_architecture(&config_pairs).unwrap_or_else(|| "unknown".to_string()),
        path,
    }
}

fn checked_paths() -> Vec<String> {
    let mut paths = BREW_PATHS.iter().map(|path| path.to_string()).collect::<Vec<_>>();
    paths.push("PATH".to_string());
    paths
}

fn explicit_brew_path() -> Option<String> {
    BREW_PATHS
        .iter()
        .find(|path| Path::new(path).exists())
        .map(|path| path.to_string())
}

fn path_brew_path() -> Option<String> {
    Command::new("/usr/bin/which")
        .arg("brew")
        .output()
        .ok()
        .and_then(|output| {
            if output.status.success() {
                let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
                (!path.is_empty()).then_some(path)
            } else {
                None
            }
        })
}

fn parse_brew_config(output: &str) -> Vec<(String, String)> {
    output
        .lines()
        .filter_map(|line| line.split_once(':'))
        .map(|(key, value)| (key.trim().to_string(), value.trim().to_string()))
        .collect()
}

fn config_value(config: &[(String, String)], key: &str) -> Option<String> {
    config
        .iter()
        .find_map(|(candidate_key, value)| (candidate_key == key).then_some(value.clone()))
        .filter(|value| !value.is_empty())
}

fn config_architecture(config: &[(String, String)]) -> Option<String> {
    let macos = config_value(config, "macOS");
    if macos.as_deref().is_some_and(|value| value.contains("arm64")) {
        return Some("arm64".to_string());
    }
    if macos.as_deref().is_some_and(|value| value.contains("x86_64")) {
        return Some("x86_64".to_string());
    }

    match std::env::consts::ARCH {
        "aarch64" | "arm64" => Some("arm64".to_string()),
        "x86_64" => Some("x86_64".to_string()),
        _ => None,
    }
}
