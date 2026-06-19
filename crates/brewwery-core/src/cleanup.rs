use napi_derive::napi;

use crate::runner::run_brew_output;

#[napi(object)]
#[allow(non_snake_case)]
pub struct CleanupPreview {
    pub items: Vec<CleanupItem>,
    pub totalSize: Option<String>,
    pub rawOutput: Option<String>,
}

#[napi(object)]
pub struct CleanupItem {
    pub name: Option<String>,
    pub path: Option<String>,
    pub size: Option<String>,
    pub kind: Option<String>,
}

#[napi(object)]
#[allow(non_snake_case)]
pub struct CleanupResult {
    pub success: bool,
    pub removedItems: Option<u32>,
    pub freedSpace: Option<String>,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
}

#[napi]
pub fn preview_cleanup() -> napi::Result<CleanupPreview> {
    let output = run_brew_output(&["cleanup", "-n"])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    Ok(parse_cleanup_preview(&output.stdout))
}

#[napi]
pub fn run_cleanup() -> napi::Result<CleanupResult> {
    let output = run_brew_output(&["cleanup"])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    let removed_items = output
        .stdout
        .lines()
        .filter(|line| line.starts_with("Removing:") || line.starts_with("Pruned "))
        .count() as u32;

    Ok(CleanupResult {
        success: true,
        removedItems: Some(removed_items),
        freedSpace: find_cleanup_total(&output.stdout),
        stdout: (!output.stdout.is_empty()).then_some(output.stdout),
        stderr: (!output.stderr.is_empty()).then_some(output.stderr),
    })
}

fn parse_cleanup_preview(raw_output: &str) -> CleanupPreview {
    let items = raw_output
        .lines()
        .filter_map(parse_cleanup_item)
        .collect::<Vec<_>>();

    CleanupPreview {
        items,
        totalSize: find_cleanup_total(raw_output),
        rawOutput: (!raw_output.is_empty()).then_some(raw_output.to_string()),
    }
}

fn parse_cleanup_item(line: &str) -> Option<CleanupItem> {
    let remainder = line
        .strip_prefix("Would remove: ")
        .or_else(|| line.strip_prefix("Would remove (broken link): "))?;
    let (path, size) = split_path_size(remainder);
    let name = path
        .rsplit('/')
        .next()
        .filter(|value| !value.is_empty())
        .map(|value| value.to_string());

    Some(CleanupItem {
        name,
        path: Some(path.to_string()),
        size,
        kind: Some(classify_cleanup_item(path).to_string()),
    })
}

fn split_path_size(value: &str) -> (&str, Option<String>) {
    if let Some((path, detail)) = value.rsplit_once(" (") {
        let detail = detail.trim_end_matches(')');
        let size = detail
            .rsplit_once(", ")
            .map(|(_, size)| size)
            .unwrap_or(detail)
            .to_string();
        return (path, Some(size));
    }

    (value, None)
}

fn classify_cleanup_item(path: &str) -> &'static str {
    if path.contains("/Caches/Homebrew/") {
        "cache"
    } else if path.contains("/Cellar/") {
        "old_version"
    } else if path.contains("/Logs/Homebrew/") {
        "download"
    } else {
        "unknown"
    }
}

fn find_cleanup_total(output: &str) -> Option<String> {
    output.lines().find_map(|line| {
        let marker = "free approximately ";
        line.find(marker).map(|index| {
            line[index + marker.len()..]
                .trim_end_matches('.')
                .trim_end_matches(" of disk space")
                .trim()
                .to_string()
        })
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_cleanup_items_and_total() {
        let output = "Would remove: /opt/homebrew/Cellar/redis/7.2.0 (12 files, 3.4MB)\nThis operation would free approximately 3.4MB of disk space.\n";
        let preview = parse_cleanup_preview(output);

        assert_eq!(preview.items.len(), 1);
        assert_eq!(preview.items[0].name.as_deref(), Some("7.2.0"));
        assert_eq!(preview.items[0].kind.as_deref(), Some("old_version"));
        assert_eq!(preview.items[0].size.as_deref(), Some("3.4MB"));
        assert_eq!(preview.totalSize.as_deref(), Some("3.4MB"));
    }

    #[test]
    fn classifies_cache_paths() {
        assert_eq!(
            classify_cleanup_item("/Users/test/Library/Caches/Homebrew/file"),
            "cache"
        );
        assert_eq!(
            classify_cleanup_item("/opt/homebrew/Cellar/redis/1"),
            "old_version"
        );
        assert_eq!(classify_cleanup_item("/tmp/file"), "unknown");
    }
}
