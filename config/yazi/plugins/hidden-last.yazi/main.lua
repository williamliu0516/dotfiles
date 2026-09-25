-- 隐藏文件排在最后。列表顺序固定为：
--   普通目录 → 普通文件 → 隐藏目录 → 隐藏文件，每组内按修改时间倒序（最新在上）。
-- 依赖 yazi 的 custom 排序（sort_by = "custom"，2026-09-19 合入主干，26.9.1 之后的版本才有）：
-- 插件给每个文件算一个 rank（越小越靠前），组别放高位、修改时间放低位，一次比较就分出先后。
local M = {}

-- 组别的权重，要大于任何 Unix 时间戳（秒），组别才能压过时间
local GROUP = 1 << 40

local function rank(folder)
  if not folder then return end
  local ranks, n = {}, 0
  for _, f in ipairs(folder.files) do
    local st = f.stat or f.cha
    local g = (st.is_hidden and 2 or 0) + (st.is_dir and 0 or 1)
    ranks[f.url.key] = g * GROUP - math.floor(st.mtime or 0)
    n = n + 1
  end
  if n > 0 then
    ya.emit("update_files", { op = fs.op("rank", { url = folder.cwd, ranks = ranks }) })
  end
end

-- 三栏里哪一栏对应这个 url：当前栏、父目录栏、预览栏（悬停在目录上时）
local function folder_of(url)
  local tab = cx.active
  if tab.current.cwd == url then return tab.current end
  if tab.parent and tab.parent.cwd == url then return tab.parent end
  local pf = tab.preview.folder
  if pf and pf.cwd == url then return pf end
end

function M:setup()
  -- 进入目录：当前栏和父目录栏（多半已在缓存里，直接排）
  ps.sub("cd", function()
    rank(cx.active.current)
    rank(cx.active.parent)
  end)
  -- 目录读取完毕：首次进入或刷新
  ps.sub("load", function(args)
    if args.stage() then rank(folder_of(args.url)) end
  end)
  -- 目录内容变化（新建、删除、改名、外部改动被 watcher 捕获）：重新算，否则新文件 rank 为 0 会插到中间
  ps.sub("patch", function(args)
    rank(folder_of(args.url))
  end)
end

return M
