import type {
  BrewDetectionResult,
  BrewInfo,
  BrewService,
  Cask,
  Formula,
  OutdatedPackage,
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
  listOutdated(): OutdatedPackage[];
  upgradePackage(request: UpgradeRequest): UpgradeResult;
  upgradeAll(): UpgradeResult;
  listServices(): BrewService[];
  startService(request: ServiceActionRequest): ServiceActionResult;
  stopService(request: ServiceActionRequest): ServiceActionResult;
  restartService(request: ServiceActionRequest): ServiceActionResult;
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
