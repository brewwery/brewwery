export type PackageKind = "formula" | "cask";

export interface Formula {
  name: string;
  fullName?: string;
  description?: string;
  installedVersion?: string;
  homepage?: string;
  dependencies?: string[];
  installedOnRequest?: boolean;
}

export interface Cask {
  token: string;
  name?: string[];
  description?: string;
  installedVersion?: string;
  homepage?: string;
}

export type BrewPackage = Formula | Cask;

export interface PackageSearchResult {
  name: string;
  kind: PackageKind;
  installed?: boolean;
}

export interface PackageInfo {
  name: string;
  token?: string;
  fullName?: string;
  displayName?: string[];
  kind: PackageKind;
  description?: string;
  homepage?: string;
  latestVersion?: string;
  installedVersion?: string;
  dependencies?: string[];
  caveats?: string;
  installed: boolean;
  rawJson?: string;
}

export interface PackageActionRequest {
  name: string;
  kind: PackageKind;
}

export interface PackageActionResult {
  name: string;
  kind: PackageKind;
  success: boolean;
  stdout?: string;
  stderr?: string;
}

export interface FavoritePackage {
  name: string;
  kind: PackageKind;
  addedAt: string;
}
