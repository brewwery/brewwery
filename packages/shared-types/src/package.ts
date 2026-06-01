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
