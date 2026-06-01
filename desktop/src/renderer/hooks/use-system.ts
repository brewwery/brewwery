import { useCallback, useEffect, useState } from "react";
import type { BrewDetectionResult, BrewInfo, IpcError } from "@brewwery/shared-types";
import { api } from "@/lib/api";

export function useSystem() {
  const [detection, setDetection] = useState<BrewDetectionResult | undefined>();
  const [system, setSystem] = useState<BrewInfo | undefined>();
  const [error, setError] = useState<IpcError | undefined>();
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    setError(undefined);
    try {
      const detectionResponse = await api.system.detectHomebrew();

      if (!detectionResponse.ok || !detectionResponse.data) {
        setError(detectionResponse.error);
        return;
      }

      setDetection(detectionResponse.data);

      if (!detectionResponse.data.found) {
        setError(detectionResponse.data.error);
        return;
      }

      const infoResponse = await api.system.getBrewInfo();

      if (infoResponse.ok && infoResponse.data) {
        setSystem(infoResponse.data);
        setError(undefined);
      } else {
        setError(infoResponse.error);
      }
    } catch (caught: unknown) {
      setError({
        code: "UNKNOWN_ERROR",
        message: caught instanceof Error ? caught.message : "Unable to load Homebrew info.",
        raw: String(caught)
      });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  return { detection, system, loading, error, refresh: load };
}
