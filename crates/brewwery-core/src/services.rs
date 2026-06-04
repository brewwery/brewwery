use napi_derive::napi;
use serde::Deserialize;

use crate::errors::BrewweryError;
use crate::runner::{run_brew, run_brew_output};

#[napi(object)]
pub struct BrewService {
    pub name: String,
    pub status: String,
    pub user: Option<String>,
    pub file: Option<String>,
    pub command: Option<String>,
}

#[napi(object)]
pub struct ServiceActionRequest {
    pub name: String,
}

#[napi(object)]
pub struct ServiceActionResult {
    pub name: String,
    pub action: String,
    pub success: bool,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
}

#[derive(Deserialize)]
struct RawService {
    name: String,
    status: Option<String>,
    user: Option<String>,
    file: Option<String>,
    command: Option<String>,
}

#[napi]
pub fn list_services() -> napi::Result<Vec<BrewService>> {
    let output = run_brew(&["services", "list", "--json"])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    parse_services_inner(&output).map_err(|error| napi::Error::from_reason(error.to_string()))
}

#[napi]
pub fn start_service(request: ServiceActionRequest) -> napi::Result<ServiceActionResult> {
    run_service_action(request.name, "start")
}

#[napi]
pub fn stop_service(request: ServiceActionRequest) -> napi::Result<ServiceActionResult> {
    run_service_action(request.name, "stop")
}

#[napi]
pub fn restart_service(request: ServiceActionRequest) -> napi::Result<ServiceActionResult> {
    run_service_action(request.name, "restart")
}

fn parse_services_inner(json: &str) -> Result<Vec<BrewService>, BrewweryError> {
    let services: Vec<RawService> = serde_json::from_str(json)
        .map_err(|error| BrewweryError::ParseFailed(error.to_string()))?;

    Ok(services.into_iter().map(normalize_service).collect())
}

fn normalize_service(service: RawService) -> BrewService {
    BrewService {
        name: service.name,
        status: normalize_status(service.status.as_deref()),
        user: service.user,
        file: service.file,
        command: service.command,
    }
}

fn normalize_status(status: Option<&str>) -> String {
    match status.unwrap_or_default().to_ascii_lowercase().as_str() {
        "started" => "started",
        "stopped" | "none" => "stopped",
        "error" => "error",
        _ => "unknown",
    }
    .to_string()
}

fn run_service_action(name: String, action: &str) -> napi::Result<ServiceActionResult> {
    validate_service_name(&name)?;

    let output = run_brew_output(&["services", action, name.as_str()])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;

    Ok(ServiceActionResult {
        name,
        action: action.to_string(),
        success: true,
        stdout: (!output.stdout.is_empty()).then_some(output.stdout),
        stderr: (!output.stderr.is_empty()).then_some(output.stderr),
    })
}

fn validate_service_name(name: &str) -> napi::Result<()> {
    if !name.is_empty()
        && name.len() <= 120
        && name.chars().all(|character| {
            character.is_ascii_alphanumeric() || matches!(character, '@' | '.' | '_' | '+' | '-')
        })
    {
        return Ok(());
    }

    Err(napi::Error::from_reason(
        BrewweryError::InvalidServiceName(name.to_string()).to_string(),
    ))
}
