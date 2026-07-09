import type { Plugin } from "@opencode-ai/plugin";
import {
  getStatusDir,
  instanceIdFrom,
  PROJECT_ID,
  SIGNAL_NUM,
} from "./constants.js";
import type { InstanceState } from "./status.js";
import { writeStatus, removeStatus } from "./status.js";

export const WaybarStatus: Plugin = async ({ project, serverUrl, $ }) => {
  const dir = getStatusDir();

  const instanceId = instanceIdFrom(new URL(serverUrl));

  const state: InstanceState = {
    instanceId,
    project: PROJECT_ID,
    status: "idle",
    permissionRequested: false,
    updatedAt: Date.now(),
  };

  let flushAgain: ReturnType<typeof setTimeout> | undefined;

  async function flush() {
    state.updatedAt = Date.now();
    await writeStatus(dir, instanceId, state);
    try {
      await $`pkill -RTMIN+${SIGNAL_NUM} waybar`;
    } catch {
      // waybar not running — fine
    }
  }

  async function scheduleFlush() {
    if (flushAgain) clearTimeout(flushAgain);
    flushAgain = setTimeout(() => {
      flush();
      flushAgain = undefined;
    }, 150);
  }

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.created":
        case "session.updated":
        case "session.status":
          state.status = "working";
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

        case "permission.updated":
          state.permissionRequested = true;
          await scheduleFlush();
          break;

        case "permission.replied":
          state.permissionRequested = false;
          await scheduleFlush();
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
      if (flushAgain) clearTimeout(flushAgain);
      await removeStatus(dir, instanceId);
      try {
        await $`pkill -RTMIN+${SIGNAL_NUM} waybar`;
      } catch {
        // waybar not running
      }
    },
  };
};
