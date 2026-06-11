import type { Cask, Formula, PackageKind } from "@brewwery/shared-types";

export function isPackageInstalled(name: string, kind: PackageKind, formulae: Formula[], casks: Cask[]) {
  const normalizedName = name.toLowerCase().trim();

  if (kind === "formula") {
    return formulae.some((formula) => formula.name.toLowerCase() === normalizedName);
  }

  return casks.some((cask) => cask.token.toLowerCase() === normalizedName);
}

export function packageDisplayName(name: string, kind: PackageKind, formulae: Formula[], casks: Cask[]) {
  if (kind === "formula") {
    return formulae.find((formula) => formula.name.toLowerCase() === name.toLowerCase())?.fullName ?? name;
  }

  return casks.find((cask) => cask.token.toLowerCase() === name.toLowerCase())?.name?.[0] ?? name;
}
