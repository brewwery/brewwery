export interface BrewfileEntry {
  type: "brew" | "cask" | "tap" | "mas" | "unknown";
  name: string;
  raw: string;
}
