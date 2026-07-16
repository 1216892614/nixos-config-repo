// island-agent-hook-omp.js — omp --hook 扩展
// omp (v16+) 使用 Bun 运行时加载 hook: --hook=<path>
// Hook 必须 export default factory(ctx) 函数
// ctx.extension.handlers 接收 claude-code-hooks 兼容事件

import { writeFileSync } from "node:fs";

const AGENT_FILE = "/tmp/island-agent.json";

function writeState(state, task) {
  const payload = JSON.stringify({
    source: "omp",
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

export default function factory(ctx) {
  const { extension } = ctx;

  // 注册 claude-code-hooks 兼容的生命周期处理器
  extension.handlers["UserPromptSubmit"] = async (input) => {
    writeState("running", input?.prompt?.slice(0, 60) || "omp working");
  };

  extension.handlers["Stop"] = async (_input) => {
    writeState("done", "");
  };

  extension.handlers["PreToolUse"] = async (_input) => {
    // 工具调用表示仍在运行中，刷新时间戳
    writeState("running", "omp working");
  };
}
