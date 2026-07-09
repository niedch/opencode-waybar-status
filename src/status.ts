import { writeFile, rename, mkdir, unlink } from "node:fs/promises";
import { unlinkSync } from "node:fs";
import path from "node:path";

export interface InstanceState {
  instanceId: string;
  project: string;
  status: "working" | "idle" | "error";
  agent?: string;
  model?: string;
  lastTool?: string;
  permissionRequested: boolean;
  updatedAt: number;
}

export async function writeStatus(
  dir: string,
  projectSlug: string,
  state: InstanceState,
): Promise<void> {
  await mkdir(dir, { recursive: true });

  const tmp = path.join(dir, `.${projectSlug}.tmp`);
  const dst = path.join(dir, `${projectSlug}.json`);

  const data = JSON.stringify(state);
  await writeFile(tmp, data, "utf-8");
  await rename(tmp, dst);
}

export async function removeStatus(
  dir: string,
  projectSlug: string,
): Promise<void> {
  const dst = path.join(dir, `${projectSlug}.json`);
  try {
    await unlink(dst);
  } catch {
    // already gone — fine
  }
}

export function removeStatusSync(dir: string, projectSlug: string): void {
  const dst = path.join(dir, `${projectSlug}.json`);
  try {
    unlinkSync(dst);
  } catch {
    // already gone — fine
  }
}
