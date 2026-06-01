import { useCallback, useEffect, useState } from "react";
import type { BrewPackage, Cask, Formula, IpcError, IpcResponse } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { usePackageStore } from "@/stores/package-store";

export function usePackages(kind: "formula" | "cask" = "formula") {
  const formulae = usePackageStore((state) => state.formulae);
  const casks = usePackageStore((state) => state.casks);
  const setFormulae = usePackageStore((state) => state.setFormulae);
  const setCasks = usePackageStore((state) => state.setCasks);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<IpcError | undefined>();

  const load = useCallback(async () => {
    setLoading(true);
    setError(undefined);

    const request: Promise<IpcResponse<Formula[] | Cask[]>> =
      kind === "formula" ? api.packages.listFormulae() : api.packages.listCasks();

    try {
      const response = await request;
      if (response.ok) {
        if (kind === "formula") setFormulae(response.data as Formula[]);
        else setCasks(response.data as Cask[]);
      } else {
        setError(response.error);
      }
    } catch (caught: unknown) {
      setError({
        code: "UNKNOWN_ERROR",
        message: caught instanceof Error ? caught.message : "Unable to load packages.",
        raw: String(caught)
      });
    } finally {
      setLoading(false);
    }
  }, [kind, setCasks, setFormulae]);

  const loadAll = useCallback(async () => {
    setLoading(true);
    setError(undefined);

    try {
      const [formulaResponse, caskResponse] = await Promise.all([api.packages.listFormulae(), api.packages.listCasks()]);

      if (formulaResponse.ok) {
        setFormulae(formulaResponse.data ?? []);
      } else if (kind === "formula") {
        setError(formulaResponse.error);
      }

      if (caskResponse.ok) {
        setCasks(caskResponse.data ?? []);
      } else if (kind === "cask") {
        setError(caskResponse.error);
      }
    } catch (caught: unknown) {
      setError({
        code: "UNKNOWN_ERROR",
        message: caught instanceof Error ? caught.message : "Unable to load packages.",
        raw: String(caught)
      });
    } finally {
      setLoading(false);
    }
  }, [kind, setCasks, setFormulae]);

  useEffect(() => {
    void load();
  }, [load]);


  const packages: BrewPackage[] = kind === "formula" ? formulae : casks;
  return { packages, loading, error, refresh: load, refreshAll: loadAll };
}
