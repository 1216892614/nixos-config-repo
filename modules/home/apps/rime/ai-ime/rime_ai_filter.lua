-- AI 候选词 filter
-- 刷新候选时把按键串和词库前 5 个候选发给 ai-ime-daemon，把它的答案放在第 2 位：
--   答案就是后面某个候选 → 把那个候选提到第 2 位
--   答案是新词（英文名词、记住的人名等）→ 插入一个 🤖 候选
-- 上屏时把按键串和上屏文字发给 daemon，让它记住用户的选择。
-- daemon 自己控制等待预算；curl 的 --max-time 只是兜底。

local CURL = "@curl@"
local MAX_CANDS = 5

local M = {}

local function json_str(s)
    local escaped = s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        return string.format("\\u%04x", c:byte())
    end)
    return '"' .. escaped .. '"'
end

local function post(env, path, body)
    local f = io.open(env.req_file, "w")
    if not f then return nil end
    f:write(body)
    f:close()
    local p = io.popen(env.curl_cmd .. path, "r")
    if not p then return nil end
    local out = p:read("*a")
    p:close()
    return out
end

function M.init(env)
    local runtime = os.getenv("XDG_RUNTIME_DIR")
    -- 路径要拼进 shell 命令，带单引号的路径直接放弃
    if not runtime or runtime:find("'", 1, true) then return end
    local dir = runtime .. "/rime-ai"
    os.execute("mkdir -p -m 700 '" .. dir .. "'")
    env.req_file = dir .. "/filter-request.json"
    env.curl_cmd = CURL .. " -s --max-time 1 --unix-socket '" .. dir .. "/daemon.sock'"
        .. " --data-binary @'" .. env.req_file .. "' http://ai-ime"

    env.commit_conn = env.engine.context.commit_notifier:connect(function(ctx)
        local text, code = ctx:get_commit_text(), ctx.input
        if text ~= "" and code ~= "" then
            post(env, "/commit", '{"input":' .. json_str(code) .. ',"text":' .. json_str(text) .. '}')
        end
    end)
end

function M.fini(env)
    if env.commit_conn then env.commit_conn:disconnect() end
end

function M.func(input, env)
    local ctx = env.engine.context
    local seg = ctx.composition:back()
    local code = seg and ctx.input:sub(seg.start + 1, seg._end) or ""
    -- 只处理普通拼写段；英文前缀、反查、辅助码等模式原样放行
    if not env.curl_cmd or not seg or not seg:has_tag("abc") or #code < 2 or not code:match("^[a-z]+$") then
        for cand in input:iter() do yield(cand) end
        return
    end

    local f, s, var = input:iter()
    local function next_cand()
        var = f(s, var)
        return var
    end

    local buf, texts = {}, {}
    while #buf < MAX_CANDS do
        local cand = next_cand()
        if not cand then break end
        buf[#buf + 1] = cand
        texts[#texts + 1] = json_str(cand.text)
    end
    -- 词库一个候选都没有时不插：AI 候选会变成第 1 位，按键数到 max_code_length 时会被自动上屏
    if not buf[1] then
        for cand in next_cand do yield(cand) end
        return
    end

    local ai = post(env, "/suggest", '{"input":' .. json_str(code) .. ',"cands":[' .. table.concat(texts, ",") .. ']}')
    local promoted = nil
    yield(buf[1])
    if ai and ai ~= "" and ai ~= buf[1].text then
        for i = 2, #buf do
            if buf[i].text == ai then promoted = i break end
        end
        if promoted then
            yield(buf[promoted])
        else
            yield(Candidate("ai", seg.start, seg._end, ai, "🤖"))
        end
    end
    for i = 2, #buf do
        if i ~= promoted then yield(buf[i]) end
    end
    for cand in next_cand do yield(cand) end
end

return M
