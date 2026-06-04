import { useCallback, useState } from "react";
import type { IpcError, PackageActionRequest, PackageActionResult } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";
import { usePackageStore } from "@/stores/package-store";

type PackageAction = "install" | "uninstall";

export function usePackageActions() {
  const setFormulae = usePackageStore((state) => state.setFormulae);
  const setCasks = usePackageStore((state) => state.setCasks);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();

  const refreshInstalled = useCallback(async () => {
    const [formulae, casks] = await Promise.all([api.packages.listFormulae(), api.packages.listCasks()]);
    if (formulae.ok) setFormulae(formulae.data ?? []);
    if (casks.ok) setCasks(casks.data ?? []);
  }, [setCasks, setFormulae]);

  const runAction = useCallback(
    async (action: PackageAction, request: PackageActionRequest): Promise<PackageActionResult | undefined> => {
      setLoading(true);
      setError(undefined);

      try {
        const response = action === "install" ? await api.packages.install(request) : await api.packages.uninstall(request);
        const command = commandFor(action, request);

        if (response.ok) {
          useHistoryStore.getState().addEntry({
            kind: action,
            status: "success",
            title: `${capitalize(action)}ed ${request.name}`,
            command,
            target: request.name,
            stdout: response.data?.stdout,
            stderr: response.data?.stderr
          });
          await refreshInstalled();
          return response.data;
        }

        if (response.error) {
          useHistoryStore.getState().addEntry({
            kind: action,
            status: "failed",
            title: `Failed to ${action} ${request.name}`,
            command,
            target: request.name,
            error: response.error,
            stderr: response.error.raw
          });
          setError(response.error);
        }
      } finally {
        setLoading(false);
      }

      return undefined;
    },
    [refreshInstalled]
  );

  return { loading, error, install: (request: PackageActionRequest) => runAction("install", request), uninstall: (request: PackageActionRequest) => runAction("uninstall", request), refreshInstalled };
}

export function commandFor(action: PackageAction, request: PackageActionRequest) {
  if (request.kind === "cask") {
    return `brew ${action} --cask ${request.name}`;
  }

  return `brew ${action} ${request.name}`;
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}
