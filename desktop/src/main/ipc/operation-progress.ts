import { randomUUID } from "node:crypto";
import { spawn } from "node:child_process";
import type { ChildProcessWithoutNullStreams } from "node:child_process";
import type { IpcMainInvokeEvent, WebContents } from "electron";
import { ipcMain } from "electron";
import type {
  IpcError,
  IpcResponse,
  PackageActionRequest,
  PackageActionResult,
  ProgressEvent,
  ProgressOperationKind,
  ProgressOperationCancelResult,
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

const MAX_CAPTURED_OUTPUT_CHARS = 200_000;
const OUTPUT_TRIM_MARKER = "\n\n[Brewwery trimmed earlier live output.]\n\n";
const FORCE_KILL_DELAY_MS = 5_000;
const OPERATION_TIMEOUT_MS: Record<ProgressOperationKind, number> = {
  install: 45 * 60 * 1_000,
  uninstall: 15 * 60 * 1_000,
  upgrade: 45 * 60 * 1_000
};

type TerminationReason = "cancelled" | "timeout";

interface ActiveOperation {
  child: ChildProcessWithoutNullStreams;
  ownerWebContentsId: number;
  timeout: NodeJS.Timeout;
  forceKill?: NodeJS.Timeout;
  terminationReason?: TerminationReason;
}

const activeOperations = new Map<string, ActiveOperation>();

export function registerOperationProgressHandlers(): void {
  ipcMain.handle(
    "operation:cancel",
    async (event, operationId: string): Promise<IpcResponse<ProgressOperationCancelResult>> =>
      toIpcResponse(() => cancelOperation(event, operationId))
  );
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
  if ([...activeOperations.values()].some((operation) => operation.ownerWebContentsId === webContents.id)) {
    throw new BrewweryIpcError(
      "OPERATION_IN_PROGRESS",
      "Another Homebrew operation is already running."
    );
  }

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
  const timeoutMs = OPERATION_TIMEOUT_MS[plan.kind];
  const started: ProgressOperationStart = {
    operationId,
    kind: plan.kind,
    command: plan.command,
    target: plan.target,
    timeoutSeconds: Math.floor(timeoutMs / 1_000)
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
  let finalized = false;
  const timeout = setTimeout(() => terminateOperation(operationId, "timeout"), timeoutMs);
  const activeOperation: ActiveOperation = {
    child,
    ownerWebContentsId: webContents.id,
    timeout
  };
  activeOperations.set(operationId, activeOperation);
  const handleOwnerDestroyed = () => terminateOperation(operationId, "cancelled");
  webContents.once("destroyed", handleOwnerDestroyed);

  const finalize = (event: ProgressEvent) => {
    if (finalized) return;
    finalized = true;
    webContents.removeListener("destroyed", handleOwnerDestroyed);
    clearActiveOperation(operationId);
    emitProgress(webContents, event);
  };

  child.stdout.on("data", (chunk: Buffer) => {
    const text = chunk.toString();
    stdout = appendBoundedOutput(stdout, text);
    emitProgress(webContents, progressChunk(operationId, plan, "stdout", text));
  });

  child.stderr.on("data", (chunk: Buffer) => {
    const text = chunk.toString();
    stderr = appendBoundedOutput(stderr, text);
    emitProgress(webContents, progressChunk(operationId, plan, "stderr", text));
  });

  child.on("error", (error) => {
    const ipcError = normalizeIpcError(error);
    finalize({
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
    if (activeOperation.terminationReason) {
      const timedOut = activeOperation.terminationReason === "timeout";
      const ipcError: IpcError = {
        code: timedOut ? "OPERATION_TIMEOUT" : "OPERATION_CANCELLED",
        message: timedOut
          ? `${plan.command} exceeded its ${formatTimeout(timeoutMs)} safety timeout.`
          : `${plan.command} was cancelled.`,
        raw: [stdout.trim(), stderr.trim()].filter(Boolean).join("\n") || undefined
      };
      finalize({
        operationId,
        kind: plan.kind,
        type: "failed",
        command: plan.command,
        target: plan.target,
        timestamp: new Date().toISOString(),
        stdout: stdout.trim(),
        stderr: stderr.trim(),
        statusCode: statusCode ?? undefined,
        error: ipcError
      });
      return;
    }

    const success = statusCode === 0;
    if (success) {
      finalize({
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

    finalize({
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

function cancelOperation(event: IpcMainInvokeEvent, operationId: string): ProgressOperationCancelResult {
  if (typeof operationId !== "string" || !/^[0-9a-f-]{36}$/i.test(operationId)) {
    return { operationId: String(operationId ?? ""), cancellationRequested: false };
  }

  const operation = activeOperations.get(operationId);
  if (!operation || operation.ownerWebContentsId !== event.sender.id) {
    return { operationId, cancellationRequested: false };
  }

  return { operationId, cancellationRequested: terminateOperation(operationId, "cancelled") };
}

function terminateOperation(operationId: string, reason: TerminationReason): boolean {
  const operation = activeOperations.get(operationId);
  if (!operation || operation.terminationReason || operation.child.exitCode !== null || operation.child.signalCode !== null) return false;

  operation.terminationReason = reason;
  if (!operation.child.kill("SIGTERM")) {
    operation.terminationReason = undefined;
    return false;
  }
  operation.forceKill = setTimeout(() => {
    if (activeOperations.has(operationId) && operation.child.exitCode === null && operation.child.signalCode === null) {
      operation.child.kill("SIGKILL");
    }
  }, FORCE_KILL_DELAY_MS);
  return true;
}

function clearActiveOperation(operationId: string) {
  const operation = activeOperations.get(operationId);
  if (!operation) return;
  clearTimeout(operation.timeout);
  if (operation.forceKill) clearTimeout(operation.forceKill);
  activeOperations.delete(operationId);
}

function formatTimeout(timeoutMs: number) {
  const minutes = Math.floor(timeoutMs / 60_000);
  return `${minutes}-minute`;
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
  if (kind === "cask") {
    validateCaskToken(request.name);
  } else {
    validateFormulaIdentifier(request.name);
  }
  return {
    name: request.name,
    kind
  };
}

function normalizeUpgradeRequest(request: UpgradeRequest): UpgradeRequest {
  const kind = request.kind === "cask" ? "cask" : "formula";
  if (kind === "cask") {
    validateCaskToken(request.name);
  } else {
    validateFormulaIdentifier(request.name);
  }
  return {
    name: request.name,
    kind
  };
}

function validateFormulaIdentifier(value: string) {
  if (!value || value.length > 120 || value.startsWith("/") || value.endsWith("/") || value.includes("//")) {
    throw new Error("invalid package name");
  }

  if (!/^[A-Za-z0-9@_.+/-]+$/.test(value)) {
    throw new Error("invalid package name");
  }
}

function validateCaskToken(value: string) {
  if (!value || value.length > 120 || !/^[A-Za-z0-9@_.+-]+$/.test(value)) {
    throw new Error("invalid cask token");
  }
}

function appendBoundedOutput(current: string, chunk: string): string {
  const combined = current + chunk;
  if (combined.length <= MAX_CAPTURED_OUTPUT_CHARS) return combined;

  const headLength = Math.floor(MAX_CAPTURED_OUTPUT_CHARS * 0.35);
  const tailLength = MAX_CAPTURED_OUTPUT_CHARS - headLength - OUTPUT_TRIM_MARKER.length;
  return `${combined.slice(0, headLength)}${OUTPUT_TRIM_MARKER}${combined.slice(-tailLength)}`;
}
