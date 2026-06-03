import { useCallback, useEffect, useState } from "react";
import type { IpcError, OutdatedPackage, UpgradeRequest, UpgradeResult } from "@brewwery/shared-types";
import { api } from "@/lib/api";

export function useUpdates() {
  const [updates, setUpdates] = useState<OutdatedPackage[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();
  const [lastChecked, setLastChecked] = useState<Date | undefined>();

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(undefined);

    try {
      const response = await api.updates.list();
      if (response.ok) {
        setUpdates(response.data ?? []);
        setLastChecked(new Date());
      } else {
        setError(response.error);
      }
    } catch (caught: unknown) {
      setError({
        code: "UNKNOWN_ERROR",
        message: caught instanceof Error ? caught.message : "Unable to load updates.",
        raw: String(caught)
      });
    } finally {
      setLoading(false);
    }
  }, []);

  const upgradePackage = useCallback(
    async (request: UpgradeRequest): Promise<UpgradeResult | undefined> => {
      setActionLoading(true);
      setError(undefined);

      try {
        const response = await api.updates.upgradePackage(request);
        if (response.ok) {
          await refresh();
          return response.data;
        }
        setError(response.error);
      } finally {
        setActionLoading(false);
      }

      return undefined;
    },
    [refresh]
  );

  const upgradeAll = useCallback(async (): Promise<UpgradeResult | undefined> => {
    setActionLoading(true);
    setError(undefined);

    try {
      const response = await api.updates.upgradeAll();
      if (response.ok) {
        await refresh();
        return response.data;
      }
      setError(response.error);
    } finally {
      setActionLoading(false);
    }

    return undefined;
  }, [refresh]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return { updates, loading, actionLoading, error, lastChecked, refresh, upgradePackage, upgradeAll };
}
