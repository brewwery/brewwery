import type { IpcError, IpcErrorCode, IpcResponse } from "@brewwery/shared-types";

export class BrewweryIpcError extends Error {
  code: IpcErrorCode;
  raw?: string;

  constructor(code: IpcErrorCode, message: string, raw?: string) {
    super(message);
    this.name = "BrewweryIpcError";
    this.code = code;
    this.raw = raw;
  }
}

export async function toIpcResponse<T>(operation: () => Promise<T> | T): Promise<IpcResponse<T>> {
  try {
    return {
      ok: true,
      data: await operation()
    };
  } catch (error) {
    return {
      ok: false,
      error: normalizeIpcError(error)
    };
  }
}

export function normalizeIpcError(error: unknown): IpcError {
  if (error instanceof BrewweryIpcError) {
    return {
      code: error.code,
      message: error.message,
      raw: error.raw
    };
  }

  if (isNodeError(error) && error.code === "EACCES") {
    return {
      code: "PERMISSION_DENIED",
      message: "Brewwery does not have permission to run this Homebrew command.",
      raw: String(error)
    };
  }

  if (error instanceof SyntaxError) {
    return {
      code: "BREW_JSON_PARSE_FAILED",
      message: "Brewwery could not parse Homebrew JSON output.",
      raw: error.message
    };
  }

  if (error instanceof Error && error.message.toLowerCase().includes("parse")) {
    return {
      code: "BREW_JSON_PARSE_FAILED",
      message: "Brewwery could not parse Homebrew JSON output.",
      raw: error.message
    };
  }

  if (error instanceof Error && error.message.toLowerCase().includes("invalid package name")) {
    return {
      code: "INVALID_PACKAGE_NAME",
      message: "The package name is not valid.",
      raw: error.message
    };
  }

  if (error instanceof Error && error.message.toLowerCase().includes("invalid cask token")) {
    return {
      code: "INVALID_CASK_TOKEN",
      message: "The cask token is not valid.",
      raw: error.message
    };
  }

  if (error instanceof Error && error.message.toLowerCase().includes("invalid service name")) {
    return {
      code: "INVALID_SERVICE_NAME",
      message: "The service name is not valid.",
      raw: error.message
    };
  }

  if (error instanceof Error && error.message.toLowerCase().includes("invalid file path")) {
    return {
      code: "INVALID_FILE_PATH",
      message: "The file path is not valid.",
      raw: error.message
    };
  }

  if (error instanceof Error && error.message.toLowerCase().includes("homebrew was not found")) {
    return {
      code: "HOMEBREW_NOT_FOUND",
      message: "Homebrew was not found in /opt/homebrew, /usr/local, or PATH.",
      raw: error.message
    };
  }

  return {
    code: "UNKNOWN_ERROR",
    message: error instanceof Error ? error.message : "An unknown error occurred.",
    raw: String(error)
  };
}

function isNodeError(error: unknown): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error;
}
