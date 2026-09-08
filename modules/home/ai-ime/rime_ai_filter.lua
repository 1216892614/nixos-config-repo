-- AI 候选词 filter
-- 从 /tmp/rime-ai/response.json 读取 daemon 返回的 AI 结果
-- 在第 2 位插入候选（第 1 位保持词库最优结果不变）
--
-- 显示状态:
--   thinking → "..."  (⏳)
--   有结果   → 候选文本 (🤖)
--   出错     → 不显示

local M = {}

local WORK_DIR = "/tmp/rime-ai"
local RESPONSE_FILE = WORK_DIR .. "/response.json"

-- ── 极简 JSON 解析（Rime lua 无第三方库）──────────────────────────────
local function json_decode(str)
    if not str or #str < 3 then return nil end
    local t = {}
    -- 匹配字符串值
    for k, v in str:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
        t[k] = v
    end
    -- 匹配数字值
    for k, v in str:gmatch('"([^"]+)"%s*:%s*(%d+)') do
        t[k] = tonumber(v)
    end
    return t
end

-- ── 读取 daemon 响应 ──────────────────────────────────────────────────
local function read_response()
    local f = io.open(RESPONSE_FILE, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    if not content or #content < 3 then return nil end
    local ok, resp = pcall(json_decode, content)
    if not ok or not resp then return nil end
    return resp
end

-- ── Filter 接口 ──────────────────────────────────────────────────────

function M.init(env)
    -- 确保工作目录存在
    os.execute("mkdir -p " .. WORK_DIR)
end

function M.func(input, env)
    local context = env.engine.context
    local raw_input = context.input

    -- 只在输入长度 >= 2 时尝试获取 AI 候选
    local ai_text = nil
    local ai_comment = ""

    if #raw_input >= 2 then
        local resp = read_response()
        if resp then
            if resp.status == "thinking" then
                ai_text = "..."
                ai_comment = "⏳"
            elseif resp.text and #resp.text > 0 then
                ai_text = resp.text
                ai_comment = "🤖"
            end
            -- error 状态: 不显示任何内容
        end
    end

    -- 输出候选: 第 1 个原候选 → AI 候选(如果有) → 其余原候选
    local idx = 0
    for cand in input:iter() do
        idx = idx + 1
        yield(cand)
        if idx == 1 and ai_text then
            local ai_cand = Candidate("ai", cand.start, cand._end, ai_text, ai_comment)
            ai_cand.quality = cand.quality - 1  -- 略低于第一候选
            yield(ai_cand)
        end
    end
end

return M
