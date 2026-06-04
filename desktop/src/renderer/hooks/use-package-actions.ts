import { useCallback, useState } from "react";
import type { IpcError, PackageActionRequest, PackageActionResult } from "@brewwery/shared-types";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";
import { usePackageStore } from "@/stores/package-store";
import { useProgressOperation } from "./use-progress-operation";

type PackageAction = "install" | "uninstall";

export function usePackageActions() {
  const setFormulae = usePackageStore((state) => state.setFormulae);
  const setCasks = usePackageStore((state) => state.setCasks);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<IpcError | undefined>();
  const progressOperation = useProgressOperation();

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
        const command = commandFor(action, request);
        const response =
          action === "install" ? await api.packages.installWithProgress(request) : await api.packages.uninstallWithProgress(request);

        if (response.ok) {
          if (!response.data) {
            throw new Error("Progress operation did not return an operation id.");
          }

          progressOperation.track(response.data);
          const event = await progressOperation.waitForCompletion(response.data.operationId);

          if (event.type === "failed") {
            const actionError = event.error ?? {
              code: action === "install" ? "PACKAGE_INSTALL_FAILED" : "PACKAGE_UNINSTALL_FAILED",
              message: `Failed to ${action} ${request.name}.`,
              raw: event.stderr || event.stdout
            } satisfies IpcError;

            useHistoryStore.getState().addEntry({
              kind: action,
              status: "failed",
              title: `Failed to ${action} ${request.name}`,
              command,
              target: request.name,
              error: actionError,
              stdout: event.stdout,
              stderr: event.stderr || actionError.raw
            });
            setError(actionError);
            return undefined;
          }

          const result = event.result as PackageActionResult | undefined;
          useHistoryStore.getState().addEntry({
            kind: action,
            status: "success",
            title: `${capitalize(action)}ed ${request.name}`,
            command,
            target: request.name,
            stdout: result?.stdout ?? event.stdout,
            stderr: result?.stderr ?? event.stderr
          });
          await refreshInstalled();
          return result;
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
    [progressOperation, refreshInstalled]
  );

  return {
    loading,
    error,
    progress: progressOperation.progress,
    clearProgress: progressOperation.clear,
    install: (request: PackageActionRequest) => runAction("install", request),
    uninstall: (request: PackageActionRequest) => runAction("uninstall", request),
    refreshInstalled
  };
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
