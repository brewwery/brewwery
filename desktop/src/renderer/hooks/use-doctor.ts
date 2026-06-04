import { useCallback, useState } from "react";
import type { DoctorResult, IpcError } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";

export function useDoctor() {
  const [result, setResult] = useState<DoctorResult | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();

  const runDoctor = useCallback(async () => {
    setLoading(true);
    setError(undefined);

    try {
      const response = await api.doctor.run();
      if (response.ok) {
        useHistoryStore.getState().addEntry({
          kind: "doctor",
          status: "success",
          title: response.data?.healthy ? "Doctor completed: healthy" : "Doctor completed with diagnostics",
          command: "brew doctor",
          stdout: response.data?.rawOutput,
          details: `${response.data?.diagnostics.length ?? 0} diagnostics`
        });
        setResult(response.data);
      } else {
        if (response.error) {
          useHistoryStore.getState().addEntry({
            kind: "doctor",
            status: "failed",
            title: "Doctor failed",
            command: "brew doctor",
            error: response.error,
            stderr: response.error.raw
          });
        }
        setError(response.error);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  return { result, loading, error, runDoctor };
}
