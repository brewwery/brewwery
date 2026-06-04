import { useCallback, useState } from "react";
import type { BrewfileExportResult, BrewfileReadResult, IpcError } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";

type BrewfileResult = BrewfileExportResult | BrewfileReadResult;

export function useBrewfile() {
  const [result, setResult] = useState<BrewfileResult | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();

  const exportBrewfile = useCallback(async () => {
    setLoading(true);
    setError(undefined);

    try {
      const response = await api.brewfile.export();
      if (response.ok) {
        useHistoryStore.getState().addEntry({
          kind: "brewfile_export",
          status: "success",
          title: "Brewfile exported",
          command: "brew bundle dump --force --file=<temp>",
          target: response.data?.path,
          stdout: response.data?.rawContent,
          details: `${response.data?.entries.length ?? 0} entries`
        });
        setResult(response.data);
      } else {
        if (response.error) {
          useHistoryStore.getState().addEntry({
            kind: "brewfile_export",
            status: "failed",
            title: "Brewfile export failed",
            command: "brew bundle dump --force --file=<temp>",
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

  const readBrewfile = useCallback(async (path: string) => {
    setLoading(true);
    setError(undefined);

    try {
      const response = await api.brewfile.read(path);
      if (response.ok) {
        setResult(response.data);
      } else {
        setError(response.error);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  return { result, loading, error, exportBrewfile, readBrewfile };
}
