import path from "node:path";

export const SIGNAL_NUM = 6;

export function getStatusDir(): string {
  const runtime =
    process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid?.() ?? 1000}`;
  return `${runtime}/opencode-waybar-status`;
}

export function projectSlug(projectPath: string): string {
  return path.basename(projectPath);
}

export function instanceIdFrom(serverUrl: URL): string {
  return serverUrl.port || serverUrl.hostname.replace(/[^a-zA-Z0-9_-]/g, "_");
}
