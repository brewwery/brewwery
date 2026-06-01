use napi_derive::napi;
use serde::Deserialize;

use crate::errors::{BrewweryError, BrewweryResult};
use crate::runner::run_brew_with_fallback;

#[napi(object)]
#[allow(non_snake_case)]
pub struct Formula {
    pub name: String,
    pub fullName: Option<String>,
    pub description: Option<String>,
    pub installedVersion: Option<String>,
    pub homepage: Option<String>,
    pub dependencies: Option<Vec<String>>,
    pub installedOnRequest: Option<bool>,
}

#[napi(object)]
#[allow(non_snake_case)]
pub struct Cask {
    pub token: String,
    pub name: Option<Vec<String>>,
    pub description: Option<String>,
    pub installedVersion: Option<String>,
    pub homepage: Option<String>,
}

#[derive(Deserialize)]
struct FormulaPayload {
    #[serde(default)]
    formulae: Vec<RawFormula>,
}

#[derive(Deserialize)]
struct RawFormula {
    name: Option<String>,
    full_name: Option<String>,
    desc: Option<String>,
    description: Option<String>,
    homepage: Option<String>,
    #[serde(default)]
    dependencies: Vec<String>,
    #[serde(default)]
    installed: Vec<InstalledFormula>,
    installed_versions: Option<Vec<String>>,
    versions: Option<Vec<String>>,
}

#[derive(Deserialize)]
struct InstalledFormula {
    version: Option<String>,
    installed_on_request: Option<bool>,
}

#[derive(Deserialize)]
struct CaskPayload {
    #[serde(default)]
    casks: Vec<RawCask>,
}

#[derive(Deserialize)]
struct RawCask {
    token: Option<String>,
    name: Option<CaskName>,
    desc: Option<String>,
    description: Option<String>,
    homepage: Option<String>,
    installed: Option<InstalledCaskVersion>,
    version: Option<String>,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum CaskName {
    One(String),
    Many(Vec<String>),
}

#[derive(Deserialize)]
#[serde(untagged)]
enum InstalledCaskVersion {
    One(String),
    Many(Vec<String>),
}

#[napi]
pub fn parse_formulae_json(json: String) -> napi::Result<Vec<Formula>> {
    parse_formulae_inner(&json).map_err(|error| napi::Error::from_reason(error.to_string()))
}

#[napi]
pub fn parse_casks_json(json: String) -> napi::Result<Vec<Cask>> {
    parse_casks_inner(&json).map_err(|error| napi::Error::from_reason(error.to_string()))
}

#[napi]
pub fn list_formulae() -> napi::Result<Vec<Formula>> {
    let output = run_brew_with_fallback(
        &["list", "--formula", "--json=v2"],
        &["list", "--formula", "--versions", "--json"],
    )
    .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    parse_formulae_json(output)
}

#[napi]
pub fn list_casks() -> napi::Result<Vec<Cask>> {
    let output = run_brew_with_fallback(
        &["list", "--cask", "--json=v2"],
        &["list", "--cask", "--versions", "--json"],
    )
    .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    parse_casks_json(output)
}

#[napi]
pub fn list_installed_formulae() -> napi::Result<Vec<Formula>> {
    list_formulae()
}

#[napi]
pub fn list_installed_casks() -> napi::Result<Vec<Cask>> {
    list_casks()
}

fn parse_formulae_inner(json: &str) -> BrewweryResult<Vec<Formula>> {
    let payload: FormulaPayload =
        serde_json::from_str(json).map_err(|error| BrewweryError::ParseFailed(error.to_string()))?;

    Ok(payload.formulae.into_iter().map(normalize_formula).collect())
}

fn parse_casks_inner(json: &str) -> BrewweryResult<Vec<Cask>> {
    let payload: CaskPayload =
        serde_json::from_str(json).map_err(|error| BrewweryError::ParseFailed(error.to_string()))?;

    Ok(payload.casks.into_iter().map(normalize_cask).collect())
}

fn normalize_formula(formula: RawFormula) -> Formula {
    let name = formula
        .name
        .clone()
        .or_else(|| formula.full_name.clone())
        .unwrap_or_else(|| "unknown".to_string());
    let installed = formula.installed.first();
    let dependencies = (!formula.dependencies.is_empty()).then_some(formula.dependencies);

    Formula {
        name,
        fullName: formula.full_name,
        description: formula.desc.or(formula.description),
        installedVersion: installed
            .and_then(|item| item.version.clone())
            .or_else(|| formula.installed_versions.and_then(|versions| versions.first().cloned()))
            .or_else(|| formula.versions.and_then(|versions| versions.first().cloned())),
        homepage: formula.homepage,
        dependencies,
        installedOnRequest: installed.and_then(|item| item.installed_on_request),
    }
}

fn normalize_cask(cask: RawCask) -> Cask {
    let token = cask.token.unwrap_or_else(|| "unknown".to_string());
    let name = match cask.name {
        Some(CaskName::One(name)) => Some(vec![name]),
        Some(CaskName::Many(names)) => Some(names),
        None => None,
    };
    let installed_version = match cask.installed {
        Some(InstalledCaskVersion::One(version)) => Some(version),
        Some(InstalledCaskVersion::Many(versions)) => versions.first().cloned(),
        None => None,
    };

    Cask {
        token,
        name,
        description: cask.desc.or(cask.description),
        installedVersion: installed_version.or(cask.version),
        homepage: cask.homepage,
    }
}
