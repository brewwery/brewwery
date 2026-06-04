import { useCallback, useState } from "react";
import type { CleanupPreview, CleanupResult, IpcError } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";

export function useCleanup() {
  const [preview, setPreview] = useState<CleanupPreview | undefined>();
  const [result, setResult] = useState<CleanupResult | undefined>();
  const [loading, setLoading] = useState(false);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();

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
      const response = await api.cleanup.run();
      if (response.ok) {
        useHistoryStore.getState().addEntry({
          kind: "cleanup",
          status: "success",
          title: "Cleanup completed",
          command: "brew cleanup",
          stdout: response.data?.stdout,
          stderr: response.data?.stderr,
          details: [
            response.data?.removedItems !== undefined ? `${response.data.removedItems} removal operations` : undefined,
            response.data?.freedSpace ? `${response.data.freedSpace} freed` : undefined
          ]
            .filter(Boolean)
            .join(" · ")
        });
        setResult(response.data);
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
  }, []);

  return { preview, result, loading, running, error, previewCleanup, runCleanup };
}
