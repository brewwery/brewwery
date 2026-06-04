import { randomUUID } from "node:crypto";
import { spawn } from "node:child_process";
import type { IpcMainInvokeEvent, WebContents } from "electron";
import { ipcMain } from "electron";
import type {
  IpcError,
  IpcResponse,
  PackageActionRequest,
  PackageActionResult,
  ProgressEvent,
  ProgressOperationKind,
  ProgressOperationStart,
  UpgradeRequest,
  UpgradeResult
} from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, normalizeIpcError, toIpcResponse } from "./errors";

type ProgressPlan =
  | {
      kind: "install" | "uninstall";
      args: string[];
      command: string;
      target: string;
      request: PackageActionRequest;
    }
  | {
      kind: "upgrade";
      args: string[];
      command: string;
      target?: string;
      request?: UpgradeRequest;
    };

export function registerOperationProgressHandlers(): void {
  ipcMain.handle(
    "packages:installProgress",
    async (event, request: PackageActionRequest): Promise<IpcResponse<ProgressOperationStart>> =>
      toIpcResponse(() => startPackageOperation(event, "install", request))
  );
  ipcMain.handle(
    "packages:uninstallProgress",
    async (event, request: PackageActionRequest): Promise<IpcResponse<ProgressOperationStart>> =>
      toIpcResponse(() => startPackageOperation(event, "uninstall", request))
  );
  ipcMain.handle(
    "updates:upgradePackageProgress",
    async (event, request: UpgradeRequest): Promise<IpcResponse<ProgressOperationStart>> =>
      toIpcResponse(() => startUpgradeOperation(event, request))
  );
  ipcMain.handle("updates:upgradeAllProgress", async (event): Promise<IpcResponse<ProgressOperationStart>> =>
    toIpcResponse(() => startUpgradeOperation(event))
  );
}

async function startPackageOperation(
  event: IpcMainInvokeEvent,
  kind: "install" | "uninstall",
  request: PackageActionRequest
): Promise<ProgressOperationStart> {
  const normalized = normalizePackageRequest(request);
  const args =
    normalized.kind === "cask" ? [kind, "--cask", normalized.name] : [kind, normalized.name];

  return startBrewProgress(event.sender, {
    kind,
    args,
    command: `brew ${args.join(" ")}`,
    target: normalized.name,
    request: normalized
  });
}

async function startUpgradeOperation(
  event: IpcMainInvokeEvent,
  request?: UpgradeRequest
): Promise<ProgressOperationStart> {
  if (!request) {
    return startBrewProgress(event.sender, {
      kind: "upgrade",
      args: ["upgrade"],
      command: "brew upgrade"
    });
  }

  const normalized = normalizeUpgradeRequest(request);
  const args =
    normalized.kind === "cask" ? ["upgrade", "--cask", normalized.name] : ["upgrade", normalized.name];

  return startBrewProgress(event.sender, {
    kind: "upgrade",
    args,
    command: `brew ${args.join(" ")}`,
    target: normalized.name,
    request: normalized
  });
}

async function startBrewProgress(webContents: WebContents, plan: ProgressPlan): Promise<ProgressOperationStart> {
  const core = await getNativeCore();
  const detection = core.detectHomebrew();
  if (!detection.found || !detection.path) {
    throw new BrewweryIpcError(
      "HOMEBREW_NOT_FOUND",
      detection.error?.message ?? "Homebrew was not found.",
      detection.error?.raw
    );
  }

  const operationId = randomUUID();
  const started: ProgressOperationStart = {
    operationId,
    kind: plan.kind,
    command: plan.command,
    target: plan.target
  };
  const startedAt = new Date().toISOString();
  let stdout = "";
  let stderr = "";

  emitProgress(webContents, {
    operationId,
    kind: plan.kind,
    type: "started",
    command: plan.command,
    target: plan.target,
    timestamp: startedAt
  });

  const child = spawn(detection.path, plan.args, {
    shell: false,
    env: {
      ...process.env,
      HOMEBREW_NO_AUTO_UPDATE: "1",
      HOMEBREW_NO_ANALYTICS: "1"
    }
  });

  child.stdout.on("data", (chunk: Buffer) => {
    const text = chunk.toString();
    stdout += text;
    emitProgress(webContents, progressChunk(operationId, plan, "stdout", text));
  });

  child.stderr.on("data", (chunk: Buffer) => {
    const text = chunk.toString();
    stderr += text;
    emitProgress(webContents, progressChunk(operationId, plan, "stderr", text));
  });

  child.on("error", (error) => {
    const ipcError = normalizeIpcError(error);
    emitProgress(webContents, {
      operationId,
      kind: plan.kind,
      type: "failed",
      command: plan.command,
      target: plan.target,
      timestamp: new Date().toISOString(),
      stdout: stdout.trim(),
      stderr: stderr.trim(),
      error: ipcError
    });
  });

  child.on("close", (statusCode) => {
    const success = statusCode === 0;
    if (success) {
      emitProgress(webContents, {
        operationId,
        kind: plan.kind,
        type: "completed",
        command: plan.command,
        target: plan.target,
        timestamp: new Date().toISOString(),
        stdout: stdout.trim(),
        stderr: stderr.trim(),
        statusCode: statusCode ?? undefined,
        result: resultFor(plan, true, stdout.trim(), stderr.trim())
      });
      return;
    }

    emitProgress(webContents, {
      operationId,
      kind: plan.kind,
      type: "failed",
      command: plan.command,
      target: plan.target,
      timestamp: new Date().toISOString(),
      stdout: stdout.trim(),
      stderr: stderr.trim(),
      statusCode: statusCode ?? undefined,
      error: errorFor(plan, stderr || stdout, statusCode)
    });
  });

  return started;
}

function emitProgress(webContents: WebContents, event: ProgressEvent) {
  if (!webContents.isDestroyed()) {
    webContents.send("operation:progress", event);
  }
}

function progressChunk(
  operationId: string,
  plan: ProgressPlan,
  type: "stdout" | "stderr",
  chunk: string
): ProgressEvent {
  return {
    operationId,
    kind: plan.kind,
    type,
    command: plan.command,
    target: plan.target,
    timestamp: new Date().toISOString(),
    chunk
  };
}

function resultFor(plan: ProgressPlan, success: boolean, stdout: string, stderr: string): PackageActionResult | UpgradeResult {
  if (plan.kind === "upgrade") {
    return {
      name: plan.request?.name,
      kind: plan.request?.kind,
      success,
      stdout,
      stderr
    };
  }

  return {
    name: plan.request.name,
    kind: plan.request.kind,
    success,
    stdout,
    stderr
  };
}

function errorFor(plan: ProgressPlan, output: string, statusCode: number | null): IpcError {
  const code =
    plan.kind === "install"
      ? "PACKAGE_INSTALL_FAILED"
      : plan.kind === "uninstall"
        ? "PACKAGE_UNINSTALL_FAILED"
        : "BREW_COMMAND_FAILED";

  return {
    code,
    message: `${plan.command} failed${typeof statusCode === "number" ? ` with exit code ${statusCode}` : ""}.`,
    raw: output.trim()
  };
}

function normalizePackageRequest(request: PackageActionRequest): PackageActionRequest {
  const kind = request.kind === "cask" ? "cask" : "formula";
  validateIdentifier(request.name, kind === "cask" ? "invalid cask token" : "invalid package name");
  return {
    name: request.name,
    kind
  };
}

function normalizeUpgradeRequest(request: UpgradeRequest): UpgradeRequest {
  const kind = request.kind === "cask" ? "cask" : "formula";
  validateIdentifier(request.name, "invalid package name");
  return {
    name: request.name,
    kind
  };
}

function validateIdentifier(value: string, message: string) {
  if (!value || value.length > 120 || !/^[A-Za-z0-9@_.+-]+$/.test(value)) {
    throw new Error(message);
  }
}
