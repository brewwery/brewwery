import { registerBrewfileHandlers } from "./brewfile";
import { registerCleanupHandlers } from "./cleanup";
import { registerDoctorHandlers } from "./doctor";
import { registerOperationProgressHandlers } from "./operation-progress";
import { registerPackageHandlers } from "./packages";
import { registerServiceHandlers } from "./services";
import { registerSettingsHandlers } from "./settings";
import { registerSystemHandlers } from "./system";
import { registerUpdateHandlers } from "./updates";

export function registerIpcHandlers(): void {
  registerSystemHandlers();
  registerSettingsHandlers();
  registerPackageHandlers();
  registerUpdateHandlers();
  registerOperationProgressHandlers();
  registerServiceHandlers();
  registerCleanupHandlers();
  registerDoctorHandlers();
  registerBrewfileHandlers();
}
