#![allow(dead_code, non_snake_case)]

mod brewfile;
mod cleanup;
mod doctor;
mod errors;
mod filesystem;
mod packages;
mod parser;
mod permissions;
mod runner;
mod services;
mod system;
mod updates;

pub use errors::{BrewweryError, BrewweryResult};
pub use brewfile::{
    export_brewfile, read_brewfile, BrewfileEntry, BrewfileExportResult, BrewfileReadResult,
};
pub use cleanup::{preview_cleanup, run_cleanup, CleanupItem, CleanupPreview, CleanupResult};
pub use doctor::{run_doctor, DoctorDiagnostic, DoctorResult};
pub use packages::{
    list_casks, list_formulae, list_installed_casks, list_installed_formulae, parse_casks_json,
    parse_formulae_json, Cask, Formula,
};
pub use services::{
    list_services, restart_service, start_service, stop_service, BrewService, ServiceActionRequest,
    ServiceActionResult,
};
pub use system::{detect_homebrew, get_brew_info, BrewDetectionResult, BrewInfo, IpcError};
pub use updates::{
    list_outdated, upgrade_all, upgrade_package, OutdatedPackage, UpgradeRequest, UpgradeResult,
};
