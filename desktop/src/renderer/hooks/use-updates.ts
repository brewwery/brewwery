import { useCallback, useEffect, useState } from "react";
import type { BrewUpdateResult, IpcError, OutdatedPackage, UpgradeRequest, UpgradeResult } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";
import { useProgressOperation } from "./use-progress-operation";

export function useUpdates() {
  const [updates, setUpdates] = useState<OutdatedPackage[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();
  const [lastChecked, setLastChecked] = useState<Date | undefined>();
  const progressOperation = useProgressOperation();

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

  const updateMetadata = useCallback(async (): Promise<BrewUpdateResult | undefined> => {
    setActionLoading(true);
    setError(undefined);

    try {
      const response = await api.updates.updateMetadata();
      if (response.ok) {
        const result = response.data;
        useHistoryStore.getState().addEntry({
          kind: "brew_update",
          status: "success",
          title: "Updated Homebrew metadata",
          command: "brew update",
          stdout: result?.stdout,
          stderr: result?.stderr
        });
        await refresh();
        return result;
      }

      if (response.error) {
        useHistoryStore.getState().addEntry({
          kind: "brew_update",
          status: "failed",
          title: "Failed to update Homebrew metadata",
          command: "brew update",
          error: response.error,
          stderr: response.error.raw
        });
      }
      setError(response.error);
    } catch (caught: unknown) {
      const actionError = {
        code: "UNKNOWN_ERROR",
        message: caught instanceof Error ? caught.message : "Unable to update Homebrew metadata.",
        raw: String(caught)
      } satisfies IpcError;
      useHistoryStore.getState().addEntry({
        kind: "brew_update",
        status: "failed",
        title: "Failed to update Homebrew metadata",
        command: "brew update",
        error: actionError,
        stderr: actionError.raw
      });
      setError(actionError);
    } finally {
      setActionLoading(false);
    }

    return undefined;
  }, [refresh]);

  const upgradePackage = useCallback(
    async (request: UpgradeRequest): Promise<UpgradeResult | undefined> => {
      setActionLoading(true);
      setError(undefined);

      try {
        const response = await api.updates.upgradePackageWithProgress(request);
        if (response.ok) {
          if (!response.data) {
            throw new Error("Progress operation did not return an operation id.");
          }

          progressOperation.track(response.data);
          const event = await progressOperation.waitForCompletion(response.data.operationId);
          const command = request.kind === "cask" ? `brew upgrade --cask ${request.name}` : `brew upgrade ${request.name}`;

          if (event.type === "failed") {
            const actionError = event.error ?? {
              code: "BREW_COMMAND_FAILED",
              message: `Failed to upgrade ${request.name}.`,
              raw: event.stderr || event.stdout
            } satisfies IpcError;

            useHistoryStore.getState().addEntry({
              kind: "upgrade",
              status: actionError.code === "OPERATION_CANCELLED" ? "cancelled" : "failed",
              title: upgradeFailureTitle(request.name, actionError),
              command,
              target: request.name,
              error: actionError,
              stdout: event.stdout,
              stderr: event.stderr || actionError.raw
            });
            setError(actionError);
            return undefined;
          }

          const result = event.result as UpgradeResult | undefined;
          useHistoryStore.getState().addEntry({
            kind: "upgrade",
            status: "success",
            title: `Upgraded ${request.name}`,
            command,
            target: request.name,
            stdout: result?.stdout ?? event.stdout,
            stderr: result?.stderr ?? event.stderr
          });
          await refresh();
          return result;
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
    [progressOperation, refresh]
  );

  const upgradeAll = useCallback(async (): Promise<UpgradeResult | undefined> => {
    setActionLoading(true);
    setError(undefined);

    try {
      const response = await api.updates.upgradeAllWithProgress();
      if (response.ok) {
        if (!response.data) {
          throw new Error("Progress operation did not return an operation id.");
        }

        progressOperation.track(response.data);
        const event = await progressOperation.waitForCompletion(response.data.operationId);

        if (event.type === "failed") {
          const actionError = event.error ?? {
            code: "BREW_COMMAND_FAILED",
            message: "Failed to upgrade all packages.",
            raw: event.stderr || event.stdout
          } satisfies IpcError;

          useHistoryStore.getState().addEntry({
            kind: "upgrade",
            status: actionError.code === "OPERATION_CANCELLED" ? "cancelled" : "failed",
            title: upgradeFailureTitle(undefined, actionError),
            command: "brew upgrade",
            error: actionError,
            stdout: event.stdout,
            stderr: event.stderr || actionError.raw
          });
          setError(actionError);
          return undefined;
        }

        const result = event.result as UpgradeResult | undefined;
        useHistoryStore.getState().addEntry({
          kind: "upgrade",
          status: "success",
          title: "Upgraded all outdated packages",
          command: "brew upgrade",
          stdout: result?.stdout ?? event.stdout,
          stderr: result?.stderr ?? event.stderr
        });
        await refresh();
        return result;
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
  }, [progressOperation, refresh]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return {
    updates,
    loading,
    actionLoading,
    error,
    lastChecked,
    progress: progressOperation.progress,
    clearProgress: progressOperation.clear,
    cancelProgress: progressOperation.cancel,
    progressCancelling: progressOperation.cancelling,
    refresh,
    updateMetadata,
    upgradePackage,
    upgradeAll
  };
}

function upgradeFailureTitle(name: string | undefined, error: IpcError) {
  const target = name ?? "all packages";
  if (error.code === "OPERATION_CANCELLED") return `Cancelled upgrade of ${target}`;
  if (error.code === "OPERATION_TIMEOUT") return `Upgrade timed out for ${target}`;
  return name ? `Failed to upgrade ${name}` : "Failed to upgrade all packages";
}
