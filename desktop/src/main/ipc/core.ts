import type {
  BrewDetectionResult,
  BrewfileExportResult,
  BrewfileReadResult,
  BrewInfo,
  BrewService,
  Cask,
  CleanupPreview,
  CleanupResult,
  DoctorResult,
  Formula,
  OutdatedPackage,
  PackageActionRequest,
  PackageActionResult,
  PackageInfo,
  PackageSearchResult,
  ServiceActionRequest,
  ServiceActionResult,
  UpgradeRequest,
  UpgradeResult
} from "@brewwery/shared-types";
import { BrewweryIpcError } from "./errors";

interface NativeBrewweryCore {
  detectHomebrew(): BrewDetectionResult;
  getBrewInfo(): BrewInfo;
  listFormulae(): Formula[];
  listCasks(): Cask[];
  searchPackages(query: string): PackageSearchResult[];
  getPackageInfo(request: PackageActionRequest): PackageInfo;
  installFormula(name: string): PackageActionResult;
  installCask(name: string): PackageActionResult;
  uninstallFormula(name: string): PackageActionResult;
  uninstallCask(name: string): PackageActionResult;
  listOutdated(): OutdatedPackage[];
  upgradePackage(request: UpgradeRequest): UpgradeResult;
  upgradeAll(): UpgradeResult;
  listServices(): BrewService[];
  startService(request: ServiceActionRequest): ServiceActionResult;
  stopService(request: ServiceActionRequest): ServiceActionResult;
  restartService(request: ServiceActionRequest): ServiceActionResult;
  previewCleanup(): CleanupPreview;
  runCleanup(): CleanupResult;
  runDoctor(): DoctorResult;
  exportBrewfile(): BrewfileExportResult;
  readBrewfile(path: string): BrewfileReadResult;
}

let nativeCorePromise: Promise<NativeBrewweryCore | undefined> | undefined;
const nativeCorePackage = "@brewwery/brewwery-core";

export async function getNativeCore(): Promise<NativeBrewweryCore> {
  nativeCorePromise ??= import(nativeCorePackage)
    .then((module) => module as NativeBrewweryCore)
    .catch(() => undefined);

  const nativeCore = await nativeCorePromise;
  if (!nativeCore) {
    throw new BrewweryIpcError(
      "UNKNOWN_ERROR",
      "Brewwery native core is not built. Run pnpm --filter @brewwery/brewwery-core build."
    );
  }

  return nativeCore;
}
