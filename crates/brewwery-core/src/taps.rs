use napi_derive::napi;

use crate::runner::{run_brew, run_brew_output};

#[napi(object)]
pub struct BrewTap {
    pub name: String,
    pub official: bool,
}

#[napi(object)]
pub struct TapActionResult {
    pub name: String,
    pub action: String,
    pub success: bool,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
}

#[napi]
pub fn list_taps() -> napi::Result<Vec<BrewTap>> {
    let output = run_brew(&["tap"]).map_err(|error| napi::Error::from_reason(error.to_string()))?;
    Ok(parse_taps(&output))
}

#[napi]
pub fn add_tap(name: String) -> napi::Result<TapActionResult> {
    validate_tap_name(&name)?;
    run_tap_action("tap", name)
}

#[napi]
pub fn remove_tap(name: String) -> napi::Result<TapActionResult> {
    validate_tap_name(&name)?;
    run_tap_action("untap", name)
}

fn run_tap_action(action: &str, name: String) -> napi::Result<TapActionResult> {
    let output = run_brew_output(&[action, name.as_str()])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;

    Ok(TapActionResult {
        name,
        action: action.to_string(),
        success: true,
        stdout: (!output.stdout.is_empty()).then_some(output.stdout),
        stderr: (!output.stderr.is_empty()).then_some(output.stderr),
    })
}

fn parse_taps(output: &str) -> Vec<BrewTap> {
    output
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(|name| BrewTap {
            name: name.to_string(),
            official: name.starts_with("homebrew/"),
        })
        .collect()
}

fn validate_tap_name(name: &str) -> napi::Result<()> {
    let mut parts = name.split('/');
    let owner = parts.next().unwrap_or_default();
    let repository = parts.next().unwrap_or_default();
    let valid = !owner.is_empty()
        && !repository.is_empty()
        && parts.next().is_none()
        && name.len() <= 160
        && owner.chars().all(is_tap_part_char)
        && repository.chars().all(is_tap_part_char);

    if valid {
        Ok(())
    } else {
        Err(napi::Error::from_reason(format!(
            "invalid tap name: {name}"
        )))
    }
}

fn is_tap_part_char(character: char) -> bool {
    character.is_ascii_alphanumeric() || matches!(character, '-' | '_' | '.')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_taps_and_marks_official_entries() {
        let taps = parse_taps("homebrew/core\nuser/tools\n");
        assert_eq!(taps.len(), 2);
        assert!(taps[0].official);
        assert!(!taps[1].official);
    }

    #[test]
    fn validates_tap_names() {
        assert!(validate_tap_name("homebrew/core").is_ok());
        assert!(validate_tap_name("user/tools-extra").is_ok());
        assert!(validate_tap_name("user/tools;whoami").is_err());
        assert!(validate_tap_name("missing-repository").is_err());
        assert!(validate_tap_name("too/many/parts").is_err());
    }
}
