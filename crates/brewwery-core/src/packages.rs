use napi_derive::napi;
use serde::Deserialize;

use crate::errors::{BrewweryError, BrewweryResult};
use crate::runner::{run_brew, run_brew_output, run_brew_with_fallback};

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

#[napi(object)]
pub struct PackageSearchResult {
    pub name: String,
    pub kind: String,
    pub installed: Option<bool>,
}

#[napi(object)]
#[allow(non_snake_case)]
pub struct PackageInfo {
    pub name: String,
    pub token: Option<String>,
    pub fullName: Option<String>,
    pub displayName: Option<Vec<String>>,
    pub kind: String,
    pub description: Option<String>,
    pub homepage: Option<String>,
    pub latestVersion: Option<String>,
    pub installedVersion: Option<String>,
    pub dependencies: Option<Vec<String>>,
    pub caveats: Option<String>,
    pub installed: bool,
    pub rawJson: Option<String>,
}

#[napi(object)]
pub struct PackageActionRequest {
    pub name: String,
    pub kind: String,
}

#[napi(object)]
pub struct PackageActionResult {
    pub name: String,
    pub kind: String,
    pub success: bool,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
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
struct FormulaInfoPayload {
    #[serde(default)]
    formulae: Vec<RawInfoFormula>,
}

#[derive(Deserialize)]
struct RawInfoFormula {
    name: Option<String>,
    full_name: Option<String>,
    desc: Option<String>,
    homepage: Option<String>,
    caveats: Option<String>,
    versions: Option<FormulaVersions>,
    #[serde(default)]
    dependencies: Vec<String>,
    #[serde(default)]
    installed: Vec<InstalledFormula>,
}

#[derive(Deserialize)]
struct FormulaVersions {
    stable: Option<String>,
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
struct CaskInfoPayload {
    #[serde(default)]
    casks: Vec<RawInfoCask>,
}

#[derive(Deserialize)]
struct RawInfoCask {
    token: Option<String>,
    full_token: Option<String>,
    name: Option<CaskName>,
    desc: Option<String>,
    homepage: Option<String>,
    version: Option<String>,
    installed: Option<InstalledCaskVersion>,
    caveats: Option<String>,
    depends_on: Option<serde_json::Value>,
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

#[napi]
pub fn search_packages(query: String) -> napi::Result<Vec<PackageSearchResult>> {
    validate_search_query(&query)?;
    let mut results = search_formulae(query.clone())?;
    results.extend(search_casks(query)?);
    Ok(results)
}

#[napi]
pub fn get_package_info(request: PackageActionRequest) -> napi::Result<PackageInfo> {
    validate_package_request(&request)?;

    if request.kind == "formula" {
        get_formula_info(request.name)
    } else {
        get_cask_info(request.name)
    }
}

#[napi]
pub fn install_formula(name: String) -> napi::Result<PackageActionResult> {
    validate_package_name(&name, "invalid package name")?;
    run_package_action("install", "formula", name, &[])
}

#[napi]
pub fn install_cask(token: String) -> napi::Result<PackageActionResult> {
    validate_package_name(&token, "invalid cask token")?;
    run_package_action("install", "cask", token, &["--cask"])
}

#[napi]
pub fn uninstall_formula(name: String) -> napi::Result<PackageActionResult> {
    validate_package_name(&name, "invalid package name")?;
    run_package_action("uninstall", "formula", name, &[])
}

#[napi]
pub fn uninstall_cask(token: String) -> napi::Result<PackageActionResult> {
    validate_package_name(&token, "invalid cask token")?;
    run_package_action("uninstall", "cask", token, &["--cask"])
}

fn search_formulae(query: String) -> napi::Result<Vec<PackageSearchResult>> {
    let output = run_brew(&["search", "--formula", query.as_str()])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    Ok(parse_search_lines(&output, "formula"))
}

fn search_casks(query: String) -> napi::Result<Vec<PackageSearchResult>> {
    let output = run_brew(&["search", "--cask", query.as_str()])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    Ok(parse_search_lines(&output, "cask"))
}

fn get_formula_info(name: String) -> napi::Result<PackageInfo> {
    validate_package_name(&name, "invalid package name")?;
    let output = run_brew(&["info", "--json=v2", name.as_str()])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    let payload: FormulaInfoPayload = serde_json::from_str(&output).map_err(|error| {
        napi::Error::from_reason(BrewweryError::ParseFailed(error.to_string()).to_string())
    })?;
    let formula = payload
        .formulae
        .into_iter()
        .next()
        .ok_or_else(|| napi::Error::from_reason("package info not found"))?;
    Ok(normalize_formula_info(formula, Some(output)))
}

fn get_cask_info(token: String) -> napi::Result<PackageInfo> {
    validate_package_name(&token, "invalid cask token")?;
    let output = run_brew(&["info", "--cask", "--json=v2", token.as_str()])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    let payload: CaskInfoPayload = serde_json::from_str(&output).map_err(|error| {
        napi::Error::from_reason(BrewweryError::ParseFailed(error.to_string()).to_string())
    })?;
    let cask = payload
        .casks
        .into_iter()
        .next()
        .ok_or_else(|| napi::Error::from_reason("package info not found"))?;
    Ok(normalize_cask_info(cask, Some(output)))
}

fn run_package_action(
    action: &str,
    kind: &str,
    name: String,
    flags: &[&str],
) -> napi::Result<PackageActionResult> {
    let mut args = vec![action];
    args.extend_from_slice(flags);
    args.push(name.as_str());
    let output =
        run_brew_output(&args).map_err(|error| napi::Error::from_reason(error.to_string()))?;

    Ok(PackageActionResult {
        name,
        kind: kind.to_string(),
        success: true,
        stdout: (!output.stdout.is_empty()).then_some(output.stdout),
        stderr: (!output.stderr.is_empty()).then_some(output.stderr),
    })
}

fn parse_formulae_inner(json: &str) -> BrewweryResult<Vec<Formula>> {
    let payload: FormulaPayload = serde_json::from_str(json)
        .map_err(|error| BrewweryError::ParseFailed(error.to_string()))?;

    Ok(payload
        .formulae
        .into_iter()
        .map(normalize_formula)
        .collect())
}

fn parse_casks_inner(json: &str) -> BrewweryResult<Vec<Cask>> {
    let payload: CaskPayload = serde_json::from_str(json)
        .map_err(|error| BrewweryError::ParseFailed(error.to_string()))?;

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
            .or_else(|| {
                formula
                    .installed_versions
                    .and_then(|versions| versions.first().cloned())
            })
            .or_else(|| {
                formula
                    .versions
                    .and_then(|versions| versions.first().cloned())
            }),
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

fn parse_search_lines(output: &str, kind: &str) -> Vec<PackageSearchResult> {
    output
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty() && !line.starts_with("==>"))
        .flat_map(|line| line.split_whitespace())
        .map(|name| PackageSearchResult {
            name: name.to_string(),
            kind: kind.to_string(),
            installed: None,
        })
        .collect()
}

fn normalize_formula_info(formula: RawInfoFormula, raw_json: Option<String>) -> PackageInfo {
    let name = formula
        .name
        .clone()
        .or_else(|| formula.full_name.clone())
        .unwrap_or_else(|| "unknown".to_string());
    let installed = formula.installed.first();
    let installed_version = installed.and_then(|item| item.version.clone());
    let dependencies = (!formula.dependencies.is_empty()).then_some(formula.dependencies);

    PackageInfo {
        name,
        token: None,
        fullName: formula.full_name,
        displayName: None,
        kind: "formula".to_string(),
        description: formula.desc,
        homepage: formula.homepage,
        latestVersion: formula.versions.and_then(|versions| versions.stable),
        installedVersion: installed_version.clone(),
        dependencies,
        caveats: formula.caveats,
        installed: installed_version.is_some(),
        rawJson: raw_json,
    }
}

fn normalize_cask_info(cask: RawInfoCask, raw_json: Option<String>) -> PackageInfo {
    let token = cask
        .token
        .clone()
        .or_else(|| cask.full_token.clone())
        .unwrap_or_else(|| "unknown".to_string());
    let display_name = match cask.name {
        Some(CaskName::One(name)) => Some(vec![name]),
        Some(CaskName::Many(names)) => Some(names),
        None => None,
    };
    let installed_version = match cask.installed {
        Some(InstalledCaskVersion::One(version)) => Some(version),
        Some(InstalledCaskVersion::Many(versions)) => versions.first().cloned(),
        None => None,
    };
    let dependencies = cask.depends_on.and_then(extract_cask_dependencies);

    PackageInfo {
        name: token.clone(),
        token: Some(token),
        fullName: cask.full_token,
        displayName: display_name,
        kind: "cask".to_string(),
        description: cask.desc,
        homepage: cask.homepage,
        latestVersion: cask.version,
        installedVersion: installed_version.clone(),
        dependencies,
        caveats: cask.caveats,
        installed: installed_version.is_some(),
        rawJson: raw_json,
    }
}

fn extract_cask_dependencies(value: serde_json::Value) -> Option<Vec<String>> {
    let mut dependencies = Vec::new();
    if let Some(object) = value.as_object() {
        for item in object.values() {
            if let Some(value) = item.as_str() {
                dependencies.push(value.to_string());
            } else if let Some(array) = item.as_array() {
                dependencies.extend(
                    array
                        .iter()
                        .filter_map(|value| value.as_str().map(ToString::to_string)),
                );
            }
        }
    }

    (!dependencies.is_empty()).then_some(dependencies)
}

fn validate_package_request(request: &PackageActionRequest) -> napi::Result<()> {
    match request.kind.as_str() {
        "formula" => validate_package_name(&request.name, "invalid package name"),
        "cask" => validate_package_name(&request.name, "invalid cask token"),
        _ => Err(napi::Error::from_reason("invalid package kind")),
    }
}

fn validate_search_query(query: &str) -> napi::Result<()> {
    if !query.trim().is_empty()
        && query.len() <= 80
        && query.chars().all(|character| {
            character.is_ascii_alphanumeric() || matches!(character, '@' | '-' | '_' | '.' | '+')
        })
    {
        return Ok(());
    }

    Err(napi::Error::from_reason("invalid package search query"))
}

fn validate_package_name(name: &str, message: &str) -> napi::Result<()> {
    if !name.is_empty()
        && name.len() <= 120
        && name.chars().all(|character| {
            character.is_ascii_alphanumeric() || matches!(character, '@' | '-' | '_' | '.' | '+')
        })
    {
        return Ok(());
    }

    Err(napi::Error::from_reason(format!("{message}: {name}")))
}
