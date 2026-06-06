import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Cask, Formula, IpcError, PackageActionRequest, PackageInfo, PackageSearchResult } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { usePackageStore } from "@/stores/package-store";
import { useDebouncedValue } from "./use-debounced-value";

export function usePackageDiscovery(query: string) {
  const debouncedQuery = useDebouncedValue(query.trim(), 350);
  const formulae = usePackageStore((state) => state.formulae);
  const casks = usePackageStore((state) => state.casks);
  const setFormulae = usePackageStore((state) => state.setFormulae);
  const setCasks = usePackageStore((state) => state.setCasks);
  const [results, setResults] = useState<PackageSearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();
  const [installedLoaded, setInstalledLoaded] = useState(false);
  const requestIdRef = useRef(0);

  const validQuery = isValidSearchQuery(debouncedQuery);
  const invalidQuery = Boolean(debouncedQuery && !validQuery);
  const formulaByName = useMemo(() => toFormulaMap(formulae), [formulae]);
  const caskByToken = useMemo(() => toCaskMap(casks), [casks]);
  const hydratedResults = useMemo(
    () =>
      results.map((result) => ({
        ...result,
        installed:
          result.kind === "formula"
            ? formulaByName.has(result.name.toLowerCase())
            : caskByToken.has(result.name.toLowerCase())
      })),
    [caskByToken, formulaByName, results]
  );

  useEffect(() => {
    let cancelled = false;

    async function loadInstalledPackages() {
      const [formulaResponse, caskResponse] = await Promise.all([api.packages.listFormulae(), api.packages.listCasks()]);
      if (cancelled) return;

      if (formulaResponse.ok) setFormulae(formulaResponse.data ?? []);
      if (caskResponse.ok) setCasks(caskResponse.data ?? []);
      setInstalledLoaded(true);
    }

    void loadInstalledPackages().catch(() => {
      if (!cancelled) setInstalledLoaded(true);
    });

    return () => {
      cancelled = true;
    };
  }, [setCasks, setFormulae]);

  useEffect(() => {
    if (!debouncedQuery) {
      setResults([]);
      setError(undefined);
      setLoading(false);
      return;
    }

    if (!validQuery) {
      requestIdRef.current += 1;
      setResults([]);
      setError(undefined);
      setLoading(false);
      return;
    }

    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;
    setLoading(true);
    setError(undefined);

    void api.packages
      .search(debouncedQuery)
      .then((response) => {
        if (requestId !== requestIdRef.current) return;
        if (response.ok) {
          setResults(response.data ?? []);
        } else {
          setError(response.error);
        }
      })
      .catch((caught: unknown) => {
        if (requestId !== requestIdRef.current) return;
        setError({
          code: "UNKNOWN_ERROR",
          message: caught instanceof Error ? caught.message : "Unable to search Homebrew packages.",
          raw: String(caught)
        });
      })
      .finally(() => {
        if (requestId === requestIdRef.current) setLoading(false);
      });

    return () => {
      requestIdRef.current += 1;
    };
  }, [debouncedQuery, validQuery]);

  const hydrateInfo = useCallback(
    (info?: PackageInfo): PackageInfo | undefined => {
      if (!info) return undefined;
      const key = (info.kind === "cask" ? (info.token ?? info.name) : info.name).toLowerCase();
      const installedPackage = info.kind === "formula" ? formulaByName.get(key) : caskByToken.get(key);

      if (!installedPackage) return info;

      return {
        ...info,
        installed: true,
        installedVersion: info.installedVersion ?? installedPackage.installedVersion
      };
    },
    [caskByToken, formulaByName]
  );

  return { debouncedQuery, error, hydrateInfo, installedLoaded, invalidQuery, loading, results: hydratedResults };
}

export function usePackageInfo() {
  const [info, setInfo] = useState<PackageInfo | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();

  const loadInfo = useCallback(async (request: PackageActionRequest) => {
    setLoading(true);
    setError(undefined);

    try {
      const response = await api.packages.info(request);
      if (response.ok) {
        setInfo(response.data);
      } else {
        setError(response.error);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  const clearInfo = useCallback(() => {
    setInfo(undefined);
    setError(undefined);
  }, []);

  return { info, loading, error, loadInfo, clearInfo };
}

export function isValidSearchQuery(query: string): boolean {
  return query.length > 0 && query.length <= 80 && /^[A-Za-z0-9@_.+-]+$/.test(query);
}

function toFormulaMap(formulae: Formula[]) {
  return new Map(formulae.map((formula) => [formula.name.toLowerCase(), formula]));
}

function toCaskMap(casks: Cask[]) {
  return new Map(casks.map((cask) => [cask.token.toLowerCase(), cask]));
}
