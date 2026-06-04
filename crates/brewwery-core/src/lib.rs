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

pub use brewfile::{
    BrewfileEntry, BrewfileExportResult, BrewfileReadResult, export_brewfile, read_brewfile,
};
pub use cleanup::{CleanupItem, CleanupPreview, CleanupResult, preview_cleanup, run_cleanup};
pub use doctor::{DoctorDiagnostic, DoctorResult, run_doctor};
pub use errors::{BrewweryError, BrewweryResult};
pub use packages::{
    Cask, Formula, PackageActionRequest, PackageActionResult, PackageInfo, PackageSearchResult,
    get_package_info, install_cask, install_formula, list_casks, list_formulae,
    list_installed_casks, list_installed_formulae, parse_casks_json, parse_formulae_json,
    search_packages, uninstall_cask, uninstall_formula,
};
pub use services::{
    BrewService, ServiceActionRequest, ServiceActionResult, list_services, restart_service,
    start_service, stop_service,
};
pub use system::{
    BrewDetectionResult, BrewInfo, BrewPathValidationResult, IpcError, clear_custom_brew_path,
    detect_homebrew, get_brew_info, set_custom_brew_path, validate_brew_path,
};
pub use updates::{
    OutdatedPackage, UpgradeRequest, UpgradeResult, list_outdated, upgrade_all, upgrade_package,
};
