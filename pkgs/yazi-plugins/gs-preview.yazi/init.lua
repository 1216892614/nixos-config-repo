--- gs-preview: Ghostscript 预览插件
--- 将 PS/EPS/AI 文件通过 gs 转为 PNG 缓存，再用 yazi 内置图片预览显示

local M = {}

function M:peek(job)
  local cache = ya.file_cache(job)
  if not cache then
    return
  end

  -- 如果缓存已存在，直接显示
  if fs.cha(cache) then
    local start = os.clock()
    ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
    local _, err = ya.image_show(cache, job.area)
    ya.preview_widget(job, err)
    return
  end

  -- 用 Ghostscript 将第一页转为 PNG
  local output, err = Command("gs")
    :args({
      "-dSAFER",
      "-dBATCH",
      "-dNOPAUSE",
      "-dFirstPage=1",
      "-dLastPage=1",
      "-sDEVICE=png16m",
      "-r150",
      "-sOutputFile=" .. tostring(cache),
      tostring(job.file.url),
    })
    :stdout(Command.NULL)
    :stderr(Command.NULL)
    :output()

  if not output or output.status.code ~= 0 then
    ya.preview_widget(job, ui.Text("Ghostscript 转换失败"):area(job.area))
    return
  end

  local start = os.clock()
  ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
  local _, show_err = ya.image_show(cache, job.area)
  ya.preview_widget(job, show_err)
end

function M:seek() end

function M:preload(job)
  local cache = ya.file_cache(job)
  if not cache or fs.cha(cache) then
    return true
  end

  local output = Command("gs")
    :args({
      "-dSAFER",
      "-dBATCH",
      "-dNOPAUSE",
      "-dFirstPage=1",
      "-dLastPage=1",
      "-sDEVICE=png16m",
      "-r150",
      "-sOutputFile=" .. tostring(cache),
      tostring(job.file.url),
    })
    :stdout(Command.NULL)
    :stderr(Command.NULL)
    :output()

  return output and output.status.code == 0
end

return M
