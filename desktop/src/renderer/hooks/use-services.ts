import { useCallback, useEffect, useState } from "react";
import type { BrewService, IpcError, ServiceActionRequest, ServiceActionResult } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";
import { useProgressOperation } from "./use-progress-operation";

type ServiceAction = "start" | "stop" | "restart";

export function useServices() {
  const [services, setServices] = useState<BrewService[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();
  const progressOperation = useProgressOperation();

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
        const response =
          action === "start"
            ? await api.services.startWithProgress(request)
            : action === "stop"
              ? await api.services.stopWithProgress(request)
              : await api.services.restartWithProgress(request);
        if (response.ok) {
          if (!response.data) throw new Error("Progress operation did not return an operation id.");
          progressOperation.track(response.data);
          const event = await progressOperation.waitForCompletion(response.data.operationId);

          if (event.type === "failed") {
            const actionError = event.error ?? {
              code: "SERVICE_COMMAND_FAILED",
              message: `Failed to ${action} ${request.name}.`,
              raw: event.stderr || event.stdout
            } satisfies IpcError;
            useHistoryStore.getState().addEntry({
              kind: "service",
              status: actionError.code === "OPERATION_CANCELLED" ? "cancelled" : "failed",
              title: serviceFailureTitle(action, request.name, actionError),
              command: `brew services ${action} ${request.name}`,
              target: request.name,
              error: actionError,
              stdout: event.stdout,
              stderr: event.stderr || actionError.raw
            });
            setError(actionError);
            return undefined;
          }

          const result = (event.result as ServiceActionResult | undefined) ?? {
            name: request.name,
            action,
            success: true,
            stdout: event.stdout,
            stderr: event.stderr
          };
          useHistoryStore.getState().addEntry({
            kind: "service",
            status: "success",
            title: `${capitalize(action)} ${request.name}`,
            command: `brew services ${action} ${request.name}`,
            target: request.name,
            stdout: result?.stdout ?? event.stdout,
            stderr: result?.stderr ?? event.stderr
          });
          await refresh();
          return result;
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
    [progressOperation, refresh]
  );

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return {
    services,
    loading,
    actionLoading,
    error,
    progress: progressOperation.progress,
    clearProgress: progressOperation.clear,
    cancelProgress: progressOperation.cancel,
    progressCancelling: progressOperation.cancelling,
    refresh,
    runAction
  };
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function serviceFailureTitle(action: ServiceAction, name: string, error: IpcError) {
  if (error.code === "OPERATION_CANCELLED") return `Cancelled ${action} for ${name}`;
  if (error.code === "OPERATION_TIMEOUT") return `Service ${action} timed out for ${name}`;
  return `Failed to ${action} ${name}`;
}
