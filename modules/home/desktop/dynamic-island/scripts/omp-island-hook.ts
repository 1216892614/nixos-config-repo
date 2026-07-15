// omp Dynamic Island hook — 写入 /tmp/island-agent.json
// omp 通过 --hook 加载此文件
// 事件接口参考 omp extension API

import { writeFileSync, readFileSync, existsSync } from "fs";

const JSON_FILE = "/tmp/island-agent.json";
const SOURCE = "omp";

function readAgents(): any[] {
  try {
    if (!existsSync(JSON_FILE)) return [];
    const raw = readFileSync(JSON_FILE, "utf-8");
    if (!raw.trim()) return [];
    const data = JSON.parse(raw);
    return Array.isArray(data) ? data : [data];
  } catch {
    return [];
  }
}

function writeAgents(agents: any[]) {
  writeFileSync(JSON_FILE, JSON.stringify(agents, null, 2));
}

function getAgentId(): string {
  return `${SOURCE}-${process.pid}`;
}

// omp hook 导出格式（推测基于事件系统）
export default {
  name: "dynamic-island",

  // 会话开始时
  onSessionStart(ctx: { model?: string; task?: string }) {
    const agents = readAgents();
    const id = getAgentId();
    // 移除旧条目
    const filtered = agents.filter((a: any) => a.id !== id);
    filtered.push({
      id,
      source: SOURCE,
      pid: process.pid,
      model: ctx.model || "unknown",
      state: "running",
      task: ctx.task || "",
      result: null,
      ts: Math.floor(Date.now() / 1000),
    });
    writeAgents(filtered);
  },

  // 用户提交 prompt 时
  onUserPrompt(ctx: { prompt?: string; model?: string }) {
    const agents = readAgents();
    const id = getAgentId();
    const existing = agents.find((a: any) => a.id === id);
    if (existing) {
      existing.task = ctx.prompt?.substring(0, 80) || existing.task;
      existing.ts = Math.floor(Date.now() / 1000);
    } else {
      agents.push({
        id,
        source: SOURCE,
        pid: process.pid,
        model: ctx.model || "unknown",
        state: "running",
        task: ctx.prompt?.substring(0, 80) || "",
        result: null,
        ts: Math.floor(Date.now() / 1000),
      });
    }
    writeAgents(agents);
  },

  // 会话结束/停止时
  onSessionEnd(ctx: { error?: boolean; result?: string }) {
    const agents = readAgents();
    const id = getAgentId();
    const agent = agents.find((a: any) => a.id === id);
    if (agent) {
      agent.state = ctx.error ? "error" : "done";
      agent.result = ctx.result || (ctx.error ? "error" : "done");
      agent.ts = Math.floor(Date.now() / 1000);
      writeAgents(agents);
    }
  },

  // 进程退出时清理
  onExit() {
    const agents = readAgents();
    const id = getAgentId();
    const agent = agents.find((a: any) => a.id === id);
    if (agent && agent.state === "running") {
      agent.state = "done";
      agent.result = "completed";
      agent.ts = Math.floor(Date.now() / 1000);
      writeAgents(agents);
    }
  },
};
