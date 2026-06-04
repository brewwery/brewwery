import { useCallback, useEffect, useState } from "react";
import type { IpcError, PackageActionRequest, PackageInfo, PackageSearchResult } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useDebouncedValue } from "./use-debounced-value";

export function usePackageDiscovery(query: string) {
  const debouncedQuery = useDebouncedValue(query.trim(), 350);
  const [results, setResults] = useState<PackageSearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();

  useEffect(() => {
    if (!debouncedQuery) {
      setResults([]);
      setError(undefined);
      setLoading(false);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(undefined);

    void api.packages.search(debouncedQuery).then((response) => {
      if (cancelled) return;
      if (response.ok) {
        setResults(response.data ?? []);
      } else {
        setError(response.error);
      }
      setLoading(false);
    });

    return () => {
      cancelled = true;
    };
  }, [debouncedQuery]);

  return { results, loading, error, debouncedQuery };
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
