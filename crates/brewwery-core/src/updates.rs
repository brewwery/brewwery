use napi_derive::napi;
use serde::Deserialize;

use crate::errors::{BrewweryError, BrewweryResult};
use crate::runner::{run_brew, run_brew_output};

#[napi(object)]
#[allow(non_snake_case)]
pub struct OutdatedPackage {
    pub name: String,
    pub kind: String,
    pub installedVersions: Vec<String>,
    pub currentVersion: Option<String>,
    pub latestVersion: Option<String>,
    pub pinned: Option<bool>,
    pub pinnedVersion: Option<String>,
}

#[napi(object)]
pub struct UpgradeRequest {
    pub name: String,
    pub kind: String,
}

#[napi(object)]
pub struct UpgradeResult {
    pub name: Option<String>,
    pub kind: Option<String>,
    pub success: bool,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
}

#[napi(object)]
pub struct BrewUpdateResult {
    pub success: bool,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
}

#[derive(Deserialize)]
struct OutdatedPayload {
    #[serde(default)]
    formulae: Vec<RawOutdatedPackage>,
    #[serde(default)]
    casks: Vec<RawOutdatedPackage>,
}

#[derive(Deserialize)]
struct RawOutdatedPackage {
    name: String,
    #[serde(default)]
    installed_versions: Vec<String>,
    current_version: Option<String>,
    pinned: Option<bool>,
    pinned_version: Option<String>,
}

#[napi]
pub fn list_outdated() -> napi::Result<Vec<OutdatedPackage>> {
    let output = run_brew(&["outdated", "--json=v2"])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    parse_outdated_inner(&output).map_err(|error| napi::Error::from_reason(error.to_string()))
}

#[napi]
pub fn update_homebrew_metadata() -> napi::Result<BrewUpdateResult> {
    let output = run_brew_output(&["update"])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;

    Ok(BrewUpdateResult {
        success: true,
        stdout: (!output.stdout.is_empty()).then_some(output.stdout),
        stderr: (!output.stderr.is_empty()).then_some(output.stderr),
    })
}

#[napi]
pub fn upgrade_package(request: UpgradeRequest) -> napi::Result<UpgradeResult> {
    let args = match request.kind {
        ref kind if kind == "formula" => {
            validate_formula_name(&request.name)?;
            vec!["upgrade", request.name.as_str()]
        }
        ref kind if kind == "cask" => {
            validate_cask_token(&request.name)?;
            vec!["upgrade", "--cask", request.name.as_str()]
        }
        _ => {
            return Err(napi::Error::from_reason(
                BrewweryError::InvalidPackageName(request.name).to_string(),
            ));
        }
    };

    let output =
        run_brew_output(&args).map_err(|error| napi::Error::from_reason(error.to_string()))?;

    Ok(UpgradeResult {
        name: Some(request.name),
        kind: Some(request.kind),
        success: true,
        stdout: (!output.stdout.is_empty()).then_some(output.stdout),
        stderr: (!output.stderr.is_empty()).then_some(output.stderr),
    })
}

#[napi]
pub fn upgrade_all() -> napi::Result<UpgradeResult> {
    let output = run_brew_output(&["upgrade"])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;

    Ok(UpgradeResult {
        name: None,
        kind: None,
        success: true,
        stdout: (!output.stdout.is_empty()).then_some(output.stdout),
        stderr: (!output.stderr.is_empty()).then_some(output.stderr),
    })
}

fn parse_outdated_inner(json: &str) -> BrewweryResult<Vec<OutdatedPackage>> {
    let payload: OutdatedPayload = serde_json::from_str(json)
        .map_err(|error| BrewweryError::ParseFailed(error.to_string()))?;

    let mut packages = Vec::with_capacity(payload.formulae.len() + payload.casks.len());
    packages.extend(
        payload
            .formulae
            .into_iter()
            .map(|item| normalize_outdated(item, "formula")),
    );
    packages.extend(
        payload
            .casks
            .into_iter()
            .map(|item| normalize_outdated(item, "cask")),
    );
    Ok(packages)
}

fn normalize_outdated(item: RawOutdatedPackage, kind: &str) -> OutdatedPackage {
    OutdatedPackage {
        name: item.name,
        kind: kind.to_string(),
        currentVersion: item.installed_versions.first().cloned(),
        latestVersion: item.current_version,
        installedVersions: item.installed_versions,
        pinned: item.pinned,
        pinnedVersion: item.pinned_version,
    }
}

fn validate_formula_name(name: &str) -> napi::Result<()> {
    if !name.is_empty()
        && name.len() <= 160
        && !name.starts_with('/')
        && !name.ends_with('/')
        && !name.contains("//")
        && name.chars().all(is_formula_identifier_char)
    {
        return Ok(());
    }

    Err(napi::Error::from_reason(
        BrewweryError::InvalidPackageName(name.to_string()).to_string(),
    ))
}

fn validate_cask_token(token: &str) -> napi::Result<()> {
    if !token.is_empty() && token.len() <= 160 && token.chars().all(is_package_token_char) {
        return Ok(());
    }

    Err(napi::Error::from_reason(
        BrewweryError::InvalidPackageName(token.to_string()).to_string(),
    ))
}

fn is_formula_identifier_char(character: char) -> bool {
    is_package_token_char(character) || character == '/'
}

fn is_package_token_char(character: char) -> bool {
    character.is_ascii_alphanumeric() || matches!(character, '@' | '.' | '_' | '+' | '-')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_formula_and_cask_updates() {
        let json = r#"{
          "formulae": [{
            "name": "redis",
            "installed_versions": ["7.2.0"],
            "current_version": "8.0.0",
            "pinned": false
          }],
          "casks": [{
            "name": "iterm2",
            "installed_versions": ["3.5.0"],
            "current_version": "3.6.0"
          }]
        }"#;

        let updates = parse_outdated_inner(json).expect("outdated JSON should parse");
        assert_eq!(updates.len(), 2);
        assert_eq!(updates[0].kind, "formula");
        assert_eq!(updates[0].currentVersion.as_deref(), Some("7.2.0"));
        assert_eq!(updates[0].latestVersion.as_deref(), Some("8.0.0"));
        assert_eq!(updates[1].kind, "cask");
    }

    #[test]
    fn validates_upgrade_targets() {
        assert!(validate_formula_name("mongodb/brew/mongodb-community").is_ok());
        assert!(validate_formula_name("redis && whoami").is_err());
        assert!(validate_cask_token("visual-studio-code").is_ok());
        assert!(validate_cask_token("homebrew/cask").is_err());
    }
}
