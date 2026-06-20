import { useCallback, useState } from "react";
import type { CleanupPreview, CleanupResult, IpcError } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";
import { useProgressOperation } from "./use-progress-operation";

export function useCleanup() {
  const [preview, setPreview] = useState<CleanupPreview | undefined>();
  const [result, setResult] = useState<CleanupResult | undefined>();
  const [loading, setLoading] = useState(false);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();
  const progressOperation = useProgressOperation();

  const previewCleanup = useCallback(async () => {
    setLoading(true);
    setError(undefined);
    setResult(undefined);

    try {
      const response = await api.cleanup.preview();
      if (response.ok) {
        setPreview(response.data);
      } else {
        setError(response.error);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  const runCleanup = useCallback(async () => {
    setRunning(true);
    setError(undefined);

    try {
      const response = await api.cleanup.runWithProgress();
      if (response.ok) {
        if (!response.data) throw new Error("Progress operation did not return an operation id.");
        progressOperation.track(response.data);
        const event = await progressOperation.waitForCompletion(response.data.operationId);

        if (event.type === "failed") {
          const actionError = event.error ?? {
            code: "CLEANUP_RUN_FAILED",
            message: "Cleanup failed.",
            raw: event.stderr || event.stdout
          } satisfies IpcError;
          useHistoryStore.getState().addEntry({
            kind: "cleanup",
            status: actionError.code === "OPERATION_CANCELLED" ? "cancelled" : "failed",
            title: cleanupFailureTitle(actionError),
            command: "brew cleanup",
            error: actionError,
            stdout: event.stdout,
            stderr: event.stderr || actionError.raw
          });
          setError(actionError);
          return;
        }

        const result = (event.result as CleanupResult | undefined) ?? {
          success: true,
          stdout: event.stdout,
          stderr: event.stderr
        };
        useHistoryStore.getState().addEntry({
          kind: "cleanup",
          status: "success",
          title: "Cleanup completed",
          command: "brew cleanup",
          stdout: result?.stdout ?? event.stdout,
          stderr: result?.stderr ?? event.stderr,
          details: [
            result?.removedItems !== undefined ? `${result.removedItems} removal operations` : undefined,
            result?.freedSpace ? `${result.freedSpace} freed` : undefined
          ]
            .filter(Boolean)
            .join(" · ")
        });
        setResult(result);
        setPreview(undefined);
      } else {
        if (response.error) {
          useHistoryStore.getState().addEntry({
            kind: "cleanup",
            status: "failed",
            title: "Cleanup failed",
            command: "brew cleanup",
            error: response.error,
            stderr: response.error.raw
          });
        }
        setError(response.error);
      }
    } finally {
      setRunning(false);
    }
  }, [progressOperation]);

  return {
    preview,
    result,
    loading,
    running,
    error,
    progress: progressOperation.progress,
    clearProgress: progressOperation.clear,
    cancelProgress: progressOperation.cancel,
    progressCancelling: progressOperation.cancelling,
    previewCleanup,
    runCleanup
  };
}

function cleanupFailureTitle(error: IpcError) {
  if (error.code === "OPERATION_CANCELLED") return "Cleanup cancelled";
  if (error.code === "OPERATION_TIMEOUT") return "Cleanup timed out";
  return "Cleanup failed";
}
