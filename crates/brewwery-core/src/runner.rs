use std::process::Command;

use crate::errors::{BrewweryError, BrewweryResult};

pub struct CommandOutput {
    pub stdout: String,
    pub stderr: String,
}

pub fn run_brew(args: &[&str]) -> BrewweryResult<String> {
    Ok(run_brew_output(args)?.stdout)
}

pub fn run_brew_output(args: &[&str]) -> BrewweryResult<CommandOutput> {
    let brew = crate::system::detect_homebrew()
        .path
        .ok_or(BrewweryError::HomebrewNotFound)?;

    let output = Command::new(brew)
        .args(args)
        .env("HOMEBREW_NO_AUTO_UPDATE", "1")
        .env("HOMEBREW_NO_ANALYTICS", "1")
        .output()
        .map_err(|error| BrewweryError::CommandFailed(error.to_string()))?;

    if !output.status.success() {
        return Err(BrewweryError::CommandFailed(
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ));
    }

    Ok(CommandOutput {
        stdout: String::from_utf8_lossy(&output.stdout).trim().to_string(),
        stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
    })
}

pub fn run_brew_with_fallback<'a>(primary_args: &[&'a str], fallback_args: &[&'a str]) -> BrewweryResult<String> {
    match run_brew(primary_args) {
        Ok(output) => Ok(output),
        Err(error) if error.to_string().contains("needless argument") => run_brew(fallback_args),
        Err(error) => Err(error),
    }
}
