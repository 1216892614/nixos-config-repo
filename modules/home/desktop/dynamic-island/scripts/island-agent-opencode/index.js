// island-agent-opencode — opencode 独立插件
// 监听 session 生命周期事件，写 /tmp/island-agent.json 供 Dynamic Island 读取
// 加载方式: opencode.json → "plugin": ["oh-my-openagent", "island-agent-opencode"]

import { writeFileSync } from "node:fs";

const AGENT_FILE = "/tmp/island-agent.json";

/**
 * @param {"running" | "done" | "error"} state
 * @param {string} task
 */
function writeState(state, task) {
  const payload = JSON.stringify({
    source: "opencode",
    state,
    task: task || "",
    ts: Math.floor(Date.now() / 1000),
  });
  try {
    writeFileSync(AGENT_FILE, payload);
  } catch {
    // 静默失败 — island 可能未运行
  }
}

/**
 * 从 EventSessionError 的 error 对象提取可读消息
 * @param {unknown} err
 * @returns {string}
 */
function extractErrorMessage(err) {
  if (err && typeof err === "object" && "data" in err) {
    const data = /** @type {{ message?: string }} */ (err).data;
    if (data && typeof data === "object" && "message" in data) {
      return String(data.message);
    }
    if ("name" in err) {
      return String(err.name);
    }
  }
  return "error";
}

/** @type {import("@opencode-ai/plugin").Plugin} */
const server = async (_input, _options) => {
  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.status": {
          const status = event.properties.status;
          if (status.type === "busy") {
            writeState("running", "opencode working");
          } else if (status.type === "idle") {
            writeState("done", "");
          } else if (status.type === "retry") {
            writeState("error", status.message || "retry");
          }
          break;
        }
        case "session.idle":
          writeState("done", "");
          break;
        case "session.error":
          writeState("error", extractErrorMessage(event.properties.error));
          break;
      }
    },
  };
};

export { server };
