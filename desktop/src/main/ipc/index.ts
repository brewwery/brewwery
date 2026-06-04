import { registerBrewfileHandlers } from "./brewfile";
import { registerCleanupHandlers } from "./cleanup";
import { registerDoctorHandlers } from "./doctor";
import { registerPackageHandlers } from "./packages";
import { registerServiceHandlers } from "./services";
import { registerSystemHandlers } from "./system";
import { registerUpdateHandlers } from "./updates";

export function registerIpcHandlers(): void {
  registerSystemHandlers();
  registerPackageHandlers();
  registerUpdateHandlers();
  registerServiceHandlers();
  registerCleanupHandlers();
  registerDoctorHandlers();
  registerBrewfileHandlers();
}
