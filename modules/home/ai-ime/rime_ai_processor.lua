-- AI IME Processor
-- 在按键时向 /tmp/rime-ai/request.json 写入当前输入
-- Processor 在 filter 之前执行，确保 daemon 在候选渲染前收到请求
--
-- 返回 kNoop(2) 不消费任何按键，只是搭便车触发请求

local M = {}

local WORK_DIR = "/tmp/rime-ai"
local REQUEST_FILE = WORK_DIR .. "/request.json"

local request_id = 0
local last_input = ""
local dir_ensured = false

-- ── 确保工作目录存在（只执行一次）───────────────────────────────────
local function ensure_dir()
    if dir_ensured then return end
    os.execute("mkdir -p " .. WORK_DIR)
    dir_ensured = true
end

-- ── 写请求文件 ───────────────────────────────────────────────────────
local function send_request(input)
    if input == last_input then return end
    last_input = input
    request_id = request_id + 1

    ensure_dir()

    -- 手动拼 JSON（避免依赖外部库）
    -- 对输入做简单转义：替换引号和反斜杠
    local safe_input = input:gsub('\\', '\\\\'):gsub('"', '\\"')
    local content = '{"id":' .. request_id .. ',"msg":"' .. safe_input .. '"}'
    local f = io.open(REQUEST_FILE, "w")
    if not f then return end
    f:write(content)
    f:close()
end

-- ── Processor 接口 ───────────────────────────────────────────────────

function M.init(env)
    -- 用时间戳初始化 request_id，避免跨 session 重复
    request_id = math.floor(os.time() % 100000) * 1000
end

function M.func(key, env)
    local context = env.engine.context
    local raw_input = context.input

    -- 只在有输入且长度 >= 2 时发请求（1 个字母太短，无意义）
    if #raw_input >= 2 then
        pcall(send_request, raw_input)
    elseif #raw_input == 0 and last_input ~= "" then
        -- 输入被清空（用户确认了选择），重置状态
        last_input = ""
    end

    -- kNoop: 不消费按键，交给后续处理器
    return 2
end

return M
