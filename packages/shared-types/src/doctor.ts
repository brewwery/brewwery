export type DoctorSeverity = "info" | "warning" | "error";

export interface DoctorDiagnostic {
  severity: DoctorSeverity;
  title: string;
  message: string;
  raw?: string;
}

export interface DoctorResult {
  healthy: boolean;
  diagnostics: DoctorDiagnostic[];
  rawOutput?: string;
}
