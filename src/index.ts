import type { Plugin } from "@opencode-ai/plugin";
import {
  getStatusDir,
  instanceIdFrom,
  projectSlug,
  SIGNAL_NUM,
} from "./constants.js";
import type { InstanceState } from "./status.js";
import { writeStatus, removeStatus, removeStatusSync } from "./status.js";

export const WaybarStatus: Plugin = async ({ project, serverUrl, $ }) => {
  const dir = getStatusDir();
  const slug = projectSlug(project.worktree);

  const instanceId = instanceIdFrom(new URL(serverUrl));

  const state: InstanceState = {
    instanceId,
    project: slug,
    status: "idle",
    permissionRequested: false,
    updatedAt: Date.now(),
  };

  let flushAgain: ReturnType<typeof setTimeout> | undefined;

  async function flush(signal = true) {
    state.updatedAt = Date.now();
    await writeStatus(dir, slug, state);
    if (signal) {
      try {
        await $`pkill -RTMIN+${SIGNAL_NUM} waybar`;
      } catch {
        // waybar not running — fine
      }
    }
  }

  async function scheduleFlush() {
    if (flushAgain) clearTimeout(flushAgain);
    flushAgain = setTimeout(() => {
      flush();
      flushAgain = undefined;
    }, 150);
  }

  // Write initial idle state immediately
  await writeStatus(dir, slug, state);

  // Heartbeat: keep file fresh so waybar can detect stale entries
  // (3s interval, so waybar's 20s stale threshold allows ~6 missed beats)
  const HEARTBEAT_MS = 3000;
  const heartbeat = setInterval(() => {
    flush(false).catch(() => {});
  }, HEARTBEAT_MS);

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.status":
          state.status =
            event.properties.status.type === "idle" ? "idle" : "working";
          await scheduleFlush();
          break;

        case "session.idle":
          state.status = "idle";
          await scheduleFlush();
          break;

        case "session.error":
          state.status = "error";
          await scheduleFlush();
          break;

        case "permission.replied":
          state.permissionRequested = false;
          await scheduleFlush();
          break;

        default:
          // permission.asked is not in SDK types but is published at runtime
          if (
            (event as unknown as { type: string }).type === "permission.asked"
          ) {
            state.permissionRequested = true;
            await scheduleFlush();
          }
          break;
      }
    },

    "tool.execute.before": async (input) => {
      state.status = "working";
      state.lastTool = input.tool;
      await scheduleFlush();
    },

    "tool.execute.after": async () => {
      // stays working; session.idle will flip to idle
    },

    dispose: async () => {
      clearInterval(heartbeat);
      if (flushAgain) clearTimeout(flushAgain);
      removeStatusSync(dir, slug);
      try {
        $`pkill -RTMIN+${SIGNAL_NUM} waybar`;
      } catch {
        // waybar not running
      }
    },
  };
};
