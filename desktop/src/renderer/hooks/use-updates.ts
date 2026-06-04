import { useCallback, useEffect, useState } from "react";
import type { IpcError, OutdatedPackage, UpgradeRequest, UpgradeResult } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";

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
          useHistoryStore.getState().addEntry({
            kind: "upgrade",
            status: "success",
            title: `Upgraded ${request.name}`,
            command: request.kind === "cask" ? `brew upgrade --cask ${request.name}` : `brew upgrade ${request.name}`,
            target: request.name,
            stdout: response.data?.stdout,
            stderr: response.data?.stderr
          });
          await refresh();
          return response.data;
        }
        if (response.error) {
          useHistoryStore.getState().addEntry({
            kind: "upgrade",
            status: "failed",
            title: `Failed to upgrade ${request.name}`,
            command: request.kind === "cask" ? `brew upgrade --cask ${request.name}` : `brew upgrade ${request.name}`,
            target: request.name,
            error: response.error,
            stderr: response.error.raw
          });
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
        useHistoryStore.getState().addEntry({
          kind: "upgrade",
          status: "success",
          title: "Upgraded all outdated packages",
          command: "brew upgrade",
          stdout: response.data?.stdout,
          stderr: response.data?.stderr
        });
        await refresh();
        return response.data;
      }
      if (response.error) {
        useHistoryStore.getState().addEntry({
          kind: "upgrade",
          status: "failed",
          title: "Failed to upgrade all packages",
          command: "brew upgrade",
          error: response.error,
          stderr: response.error.raw
        });
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
