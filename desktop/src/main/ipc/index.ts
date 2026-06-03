import { registerPackageHandlers } from "./packages";
import { registerServiceHandlers } from "./services";
import { registerSystemHandlers } from "./system";
import { registerUpdateHandlers } from "./updates";

export function registerIpcHandlers(): void {
  registerSystemHandlers();
  registerPackageHandlers();
  registerUpdateHandlers();
  registerServiceHandlers();
}
