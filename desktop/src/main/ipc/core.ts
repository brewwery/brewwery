import type { BrewDetectionResult, BrewInfo, Cask, Formula } from "@brewwery/shared-types";
import { BrewweryIpcError } from "./errors";

interface NativeBrewweryCore {
  detectHomebrew(): BrewDetectionResult;
  getBrewInfo(): BrewInfo;
  listFormulae(): Formula[];
  listCasks(): Cask[];
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
