export type BrewfileEntryKind = "brew" | "cask" | "tap" | "mas" | "service" | "unknown";

export interface BrewfileEntry {
  kind: BrewfileEntryKind;
  name: string;
  raw: string;
}

export interface BrewfileReadResult {
  path: string;
  entries: BrewfileEntry[];
  rawContent: string;
}

export interface BrewfileExportResult {
  path?: string;
  entries: BrewfileEntry[];
  rawContent: string;
}
