-- AI 候选词 filter（零 fork 文件 IPC）
-- 通信方式：通过 $XDG_RUNTIME_DIR/rime-ai/ 下的文件与 daemon 交互
--   request.json — 本 filter 写入，daemon 轮询读取
--   result.txt   — daemon 写入 "code\tresult"，本 filter 读取
--   commit.txt   — 上屏时写入 "code\ttext"，daemon 轮询读取
-- Lua 侧完全不 fork 子进程，只做文件读写（微秒级）。

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

-- 原子写文件：先写 tmp 再 rename，防止 daemon 读到半截
local function atomic_write(path, tmp, content)
    local f = io.open(tmp, "w")
    if not f then return false end
    f:write(content)
    f:close()
    os.rename(tmp, path)
    return true
end

-- 读取结果文件：格式 "code\tresult"
local function read_result(path)
    local f = io.open(path, "r")
    if not f then return nil, nil end
    local line = f:read("*l")
    f:close()
    if not line then return nil, nil end
    local tab = line:find("\t", 1, true)
    if not tab then return nil, nil end
    return line:sub(1, tab - 1), line:sub(tab + 1)
end

function M.init(env)
    local runtime = os.getenv("XDG_RUNTIME_DIR")
    if not runtime or runtime:find("'", 1, true) then return end
    local dir = runtime .. "/rime-ai"
    os.execute("mkdir -p -m 700 '" .. dir .. "'")
    env.dir = dir
    env.request_path = dir .. "/request.json"
    env.request_tmp  = dir .. "/request.json.tmp"
    env.result_path  = dir .. "/result.txt"
    env.commit_path  = dir .. "/commit.txt"
    env.commit_tmp   = dir .. "/commit.txt.tmp"

    env.commit_conn = env.engine.context.commit_notifier:connect(function(ctx)
        local text, code = ctx:get_commit_text(), ctx.input
        if text ~= "" and code ~= "" then
            atomic_write(env.commit_path, env.commit_tmp, code .. "\t" .. text)
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
    if not env.dir or not seg or not seg:has_tag("abc") or #code < 2 or not code:match("^[a-z]+$") then
        for cand in input:iter() do yield(cand) end
        return
    end

    -- 收集词库候选
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
    if not buf[1] then
        for cand in next_cand do yield(cand) end
        return
    end

    -- 1) 同步轮询：读结果文件，看 daemon 是否已算好上一次的结果
    local res_code, ai = read_result(env.result_path)
    local promoted = nil
    local has_ai = res_code == code and ai and ai ~= "" and ai ~= buf[1].text

    yield(buf[1])
    if has_ai then
        -- AI 结果就绪 → 放第 2 位
        for i = 2, #buf do
            if buf[i].text == ai then promoted = i break end
        end
        if promoted then
            yield(buf[promoted])
        else
            yield(Candidate("ai", seg.start, seg._end, ai, "🤖"))
        end
        for i = 2, #buf do
            if i ~= promoted then yield(buf[i]) end
        end
    else
        -- AI 未就绪 → 正常候选序 + 加载提示在末尾
        for i = 2, #buf do yield(buf[i]) end
        yield(Candidate("ai", seg.start, seg._end, "...", "⏳"))
    end
    for cand in next_cand do yield(cand) end

    -- 2) 写请求文件：daemon 检测到后开始计算
    atomic_write(env.request_path, env.request_tmp,
        '{"input":' .. json_str(code) .. ',"cands":[' .. table.concat(texts, ",") .. ']}')
end

return M
