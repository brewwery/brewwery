import { useCallback, useEffect, useState } from "react";
import type { BrewService, IpcError, ServiceActionRequest, ServiceActionResult } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";

type ServiceAction = "start" | "stop" | "restart";

export function useServices() {
  const [services, setServices] = useState<BrewService[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(undefined);

    try {
      const response = await api.services.list();
      if (response.ok) {
        setServices(response.data ?? []);
      } else {
        setError(response.error);
      }
    } catch (caught: unknown) {
      setError({
        code: "UNKNOWN_ERROR",
        message: caught instanceof Error ? caught.message : "Unable to load services.",
        raw: String(caught)
      });
    } finally {
      setLoading(false);
    }
  }, []);

  const runAction = useCallback(
    async (action: ServiceAction, request: ServiceActionRequest): Promise<ServiceActionResult | undefined> => {
      setActionLoading(true);
      setError(undefined);

      try {
        const response = await api.services[action](request);
        if (response.ok) {
          useHistoryStore.getState().addEntry({
            kind: "service",
            status: "success",
            title: `${capitalize(action)} ${request.name}`,
            command: `brew services ${action} ${request.name}`,
            target: request.name,
            stdout: response.data?.stdout,
            stderr: response.data?.stderr
          });
          await refresh();
          return response.data;
        }
        if (response.error) {
          useHistoryStore.getState().addEntry({
            kind: "service",
            status: "failed",
            title: `Failed to ${action} ${request.name}`,
            command: `brew services ${action} ${request.name}`,
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

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return { services, loading, actionLoading, error, refresh, runAction };
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}
