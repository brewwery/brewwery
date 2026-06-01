export interface BrewUpdate {
  name: string;
  currentVersion?: string;
  latestVersion?: string;
  kind: "formula" | "cask";
}
