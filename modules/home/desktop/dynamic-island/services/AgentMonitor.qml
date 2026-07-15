import Quickshell
import Quickshell.Io
import QtQuick

// Agent 监控：FileView 监听 + PID 轮询双通道
Item {
  id: root
  visible: false
  width: 0; height: 0

  property var agents: []             // 当前 agent 列表
  property int activeCount: 0         // running 状态数量
  property bool hasAgents: activeCount > 0

  // ── Hook 通道：FileView 监听 JSON ───────────────────────────────────
  FileView {
    id: agentFile
    path: "/tmp/island-agent.json"
    watchChanges: true
    printErrors: false
  }

  Connections {
    target: agentFile
    function onLoadedChanged() { root.parseAgents() }
  }

  Timer {
    // 首次加载 + 定期重解析（防 FileView 通知丢失）
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.parseAgents()
  }

  function parseAgents() {
    try {
      if (!agentFile.loaded) return
      var raw = agentFile.text()
      if (!raw || raw.trim() === "") {
        agents = []
        activeCount = 0
        return
      }
      var data = JSON.parse(raw)
      if (!Array.isArray(data)) data = [data]
      agents = data
      activeCount = data.filter(a => a.state === "running").length
    } catch (e) {
      // JSON 解析失败，保持现状
    }
  }

  // ── 轮询通道：PID 存活检查 ──────────────────────────────────────────
  Timer {
    interval: 2000
    running: root.activeCount > 0
    repeat: true
    onTriggered: root.checkPids()
  }

  property int _checkIdx: 0

  Process {
    id: pidChecker
    onExited: (code, status) => {
      if (code !== 0) {
        // 进程已死
        root.markDead(root._checkIdx)
      }
      root._checkIdx++
      root.checkNextPid()
    }
  }

  function checkPids() {
    _checkIdx = 0
    checkNextPid()
  }

  function checkNextPid() {
    while (_checkIdx < agents.length) {
      var agent = agents[_checkIdx]
      if (agent.state === "running" && agent.pid) {
        pidChecker.command = ["kill", "-0", agent.pid.toString()]
        pidChecker.running = true
        return
      }
      _checkIdx++
    }
  }

  function markDead(idx) {
    if (idx >= agents.length) return
    var updated = agents.slice()
    updated[idx].state = "dead"
    updated[idx].result = "killed"
    agents = updated
    activeCount = agents.filter(a => a.state === "running").length
    // 写回文件
    writeAgents()
  }

  function writeAgents() {
    // 通过 Process 写回 JSON
    writeProc.command = ["bash", "-c", "echo '" + JSON.stringify(agents) + "' > /tmp/island-agent.json"]
    writeProc.running = true
  }

  Process {
    id: writeProc
  }

  // ── 清理过期条目 ─────────────────────────────────────────────────────
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.cleanupExpired()
  }

  function cleanupExpired() {
    var now = Date.now() / 1000
    var changed = false
    var updated = agents.filter(a => {
      if (a.state === "dead" && (now - a.ts) > 10) { changed = true; return false }
      if ((a.state === "done" || a.state === "error") && (now - a.ts) > 30) { changed = true; return false }
      return true
    })
    if (changed) {
      agents = updated
      activeCount = updated.filter(a => a.state === "running").length
      writeAgents()
    }
  }
}
