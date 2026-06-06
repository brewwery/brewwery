import type {
  BrewDetectionResult,
  BrewUpdateResult,
  BrewfileExportResult,
  BrewfileReadResult,
  BrewInfo,
  BrewPathValidationResult,
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
import { getStoredHomebrewPath } from "../settings-storage";
import { BrewweryIpcError } from "./errors";

interface NativeBrewweryCore {
  detectHomebrew(): BrewDetectionResult;
  getBrewInfo(): BrewInfo;
  validateBrewPath(path: string): BrewPathValidationResult;
  setCustomBrewPath(path: string): BrewPathValidationResult;
  clearCustomBrewPath(): void;
  listFormulae(): Formula[];
  listCasks(): Cask[];
  searchPackages(query: string): PackageSearchResult[];
  getPackageInfo(request: PackageActionRequest): PackageInfo;
  installFormula(name: string): PackageActionResult;
  installCask(name: string): PackageActionResult;
  uninstallFormula(name: string): PackageActionResult;
  uninstallCask(name: string): PackageActionResult;
  listOutdated(): OutdatedPackage[];
  updateHomebrewMetadata(): BrewUpdateResult;
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

  applyStoredHomebrewPath(nativeCore);
  return nativeCore;
}

function applyStoredHomebrewPath(nativeCore: NativeBrewweryCore) {
  const storedPath = getStoredHomebrewPath();
  if (storedPath) {
    const validation = nativeCore.setCustomBrewPath(storedPath);
    if (!validation.valid) {
      nativeCore.clearCustomBrewPath();
    }
  } else {
    nativeCore.clearCustomBrewPath();
  }
}
