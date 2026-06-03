export type ServiceStatus = "started" | "stopped" | "error" | "unknown";

export interface BrewService {
  name: string;
  status: ServiceStatus;
  user?: string;
  file?: string;
  command?: string;
}

export interface ServiceActionRequest {
  name: string;
}

export interface ServiceActionResult {
  name: string;
  action: "start" | "stop" | "restart";
  success: boolean;
  stdout?: string;
  stderr?: string;
}
