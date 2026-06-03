import type { PackageKind } from "./package";

export type { PackageKind } from "./package";

export interface OutdatedPackage {
  name: string;
  kind: PackageKind;
  installedVersions: string[];
  currentVersion?: string;
  latestVersion?: string;
  pinned?: boolean;
  pinnedVersion?: string;
}

export interface UpgradeRequest {
  name: string;
  kind: PackageKind;
}

export interface UpgradeResult {
  name?: string;
  kind?: PackageKind;
  success: boolean;
  stdout?: string;
  stderr?: string;
}
