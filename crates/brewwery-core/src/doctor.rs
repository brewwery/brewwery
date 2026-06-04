use napi_derive::napi;

use crate::runner::run_brew_output_permissive;

#[napi(object)]
pub struct DoctorDiagnostic {
    pub severity: String,
    pub title: String,
    pub message: String,
    pub raw: Option<String>,
}

#[napi(object)]
#[allow(non_snake_case)]
pub struct DoctorResult {
    pub healthy: bool,
    pub diagnostics: Vec<DoctorDiagnostic>,
    pub rawOutput: Option<String>,
}

#[napi]
pub fn run_doctor() -> napi::Result<DoctorResult> {
    let output = run_brew_output_permissive(&["doctor"])
        .map_err(|error| napi::Error::from_reason(error.to_string()))?;
    let raw_output = [output.stdout.as_str(), output.stderr.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("\n");
    let diagnostics = parse_doctor_output(&raw_output);
    let healthy = diagnostics.is_empty() && raw_output.to_lowercase().contains("ready to brew");

    Ok(DoctorResult {
        healthy,
        diagnostics,
        rawOutput: (!raw_output.is_empty()).then_some(raw_output),
    })
}

fn parse_doctor_output(output: &str) -> Vec<DoctorDiagnostic> {
    let mut diagnostics = Vec::new();
    let mut current_title: Option<String> = None;
    let mut current_lines: Vec<String> = Vec::new();

    for line in output.lines() {
        if let Some(title) = line.strip_prefix("Warning: ") {
            push_diagnostic(&mut diagnostics, current_title.take(), &mut current_lines);
            current_title = Some(title.trim().to_string());
        } else if line.trim().is_empty() {
            if current_title.is_some() && !current_lines.is_empty() {
                push_diagnostic(&mut diagnostics, current_title.take(), &mut current_lines);
            }
        } else if current_title.is_some() {
            current_lines.push(line.to_string());
        }
    }

    push_diagnostic(&mut diagnostics, current_title, &mut current_lines);
    diagnostics
}

fn push_diagnostic(
    diagnostics: &mut Vec<DoctorDiagnostic>,
    title: Option<String>,
    lines: &mut Vec<String>,
) {
    if let Some(title) = title {
        let message = lines.join("\n").trim().to_string();
        let raw = if message.is_empty() {
            title.clone()
        } else {
            format!("Warning: {title}\n{message}")
        };

        diagnostics.push(DoctorDiagnostic {
            severity: "warning".to_string(),
            title,
            message,
            raw: Some(raw),
        });
        lines.clear();
    }
}
