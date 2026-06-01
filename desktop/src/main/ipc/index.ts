import { registerPackageHandlers } from "./packages";
import { registerSystemHandlers } from "./system";

export function registerIpcHandlers(): void {
  registerSystemHandlers();
  registerPackageHandlers();
}
