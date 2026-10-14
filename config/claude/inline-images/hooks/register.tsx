// 对话里直接显示 Claude 读到、截到的图：画在 "Read N files" 那一行（或工具结果）下面，和手机 App 一样的位置。
// 终端得认 kitty 图片协议（Ghostty、kitty）；在 tmux 里要经 tmux-kgp 启动（zshrc 里的 claude 函数），
// 没有它 Claude Code 在 tmux 里不画图，这里也就什么都不加。
import type { Register } from 'claude-code'

type Pic = { b64: string; mime: string; label: string }
type Png = { path: string; w: number; h: number; cw: number; ch: number; kitty: boolean }

// 同一个工具调用每次重画都会来一遍：转好的 PNG 按调用记住，只跑一次 claude-img
const cache = new Map<string, Promise<Png | null>>()

// 工具结果里的图片块：Read 的 { type: image, file: { base64, type } }，
// MCP 的 { type: image, data, mimeType }，API 的 { type: image, source: { data, media_type } }
function walk(v: unknown, out: Omit<Pic, 'label'>[], depth = 0): void {
  if (depth > 6 || v === null || typeof v !== 'object') return
  if (Array.isArray(v)) {
    for (const x of v) walk(x, out, depth + 1)
    return
  }
  const o = v as Record<string, any>
  if (o.type === 'image') {
    const data = o.data ?? o.source?.data ?? o.file?.base64
    const mime = o.mimeType ?? o.media_type ?? o.source?.media_type ?? o.file?.type ?? 'image/png'
    if (typeof data === 'string' && data.length > 0) {
      out.push({ b64: data, mime })
      return
    }
  }
  for (const x of Object.values(o)) walk(x, out, depth + 1)
}

function picsOf(tool: string, input: unknown, output: unknown): Pic[] {
  const found: Omit<Pic, 'label'>[] = []
  walk(output, found)
  const path = (input as any)?.file_path
  const name = typeof path === 'string' ? path.split('/').pop()! : tool.replace(/^mcp__/, '').replace(/__/g, ' ')
  return found.map((p, i) => ({ ...p, label: found.length > 1 ? `${name} #${i + 1}` : name }))
}

async function enabled($: any): Promise<boolean> {
  if (await $.env.get('TMUX')) return Boolean(await $.env.get('CLAUDE_CODE_FORCE_TERMINAL_IMAGES'))
  const term = await $.env.get('TERM')
  return term === 'xterm-ghostty' || term === 'xterm-kitty'
}

function toPng($: any, key: string, pic: Pic): Promise<Png | null> {
  let p = cache.get(key)
  if (!p) {
    p = (async () => {
      const home = await $.env.get('HOME')
      const r = await $.process.run([`${home}/.local/bin/claude-img`, 'png', pic.mime], { stdin: pic.b64, timeoutMs: 8000 })
      return r.exitCode === 0 ? (JSON.parse(r.stdout) as Png) : null
    })().catch(() => null)
    cache.set(key, p)
  }
  return p
}

// 保持宽高比：最宽 maxCols 格、最高 maxRows 行，小图最多放大到 2 倍
function fit(png: Png, maxCols: number, maxRows: number) {
  const cw = png.cw > 0 ? png.cw : 8
  const ch = png.ch > 0 ? png.ch : 18
  let columns = Math.max(1, Math.min(maxCols, Math.ceil((png.w * 2) / cw)))
  let rows = Math.max(1, Math.round((columns * cw * png.h) / (png.w * ch)))
  if (rows > maxRows) {
    rows = maxRows
    columns = Math.max(1, Math.round((rows * ch * png.w) / (png.h * cw)))
  }
  return { columns: Math.min(columns, 255), rows: Math.min(rows, 255) }
}

async function withPics($: any, e: any, base: any, items: { key: string; pic: Pic }[]) {
  if (items.length === 0 || !(await enabled($))) return base
  const pngs = await Promise.all(items.map(it => toPng($, it.key, it.pic)))
  // 现在没有能显示的终端在看（比如只从 iPad 网页终端连着）：不画，免得留一片空格子
  const shown = items.map((it, i) => ({ ...it, png: pngs[i] })).filter(x => x.png?.kitty)
  if (shown.length === 0) return base
  const { Box, Text, Image } = $.ui.resolve(e)
  const maxCols = Math.max(10, Math.min((e.viewport?.columns ?? 80) - 6, 100))
  const maxRows = Math.max(6, Math.min(24, Math.floor((e.viewport?.rows ?? 40) / 2)))
  return (
    <Box flexDirection="column">
      {base}
      {shown.map(({ key, pic, png }) => (
        <Box key={key} flexDirection="column" paddingLeft={2} marginTop={1}>
          {shown.length > 1 ? <Text dimColor>{pic.label}</Text> : null}
          <Image key={key} source={{ file: png!.path, format: 'png' }} {...fit(png!, maxCols, maxRows)} alt={`[${pic.label}]`} />
        </Box>
      ))}
    </Box>
  )
}

export const register: Register = on => {
  // 连续的读文件、搜索折成一行 "Read 3 files"：图画在这一行下面
  on('ui.render', { component: 'ToolGroup' }, async ($, e, next) => {
    const base = await next(e)
    if (e.surface !== 'terminal' || e.props.isExpanded) return base
    const items = e.props.calls.flatMap((c, ci) =>
      c.isRunning || c.isErrored
        ? []
        : picsOf(c.tool, c.input, c.output).map((pic, i) => ({ key: `${c.tool_use_id ?? ci}-${i}`, pic })),
    )
    return withPics($, e, base, items)
  })

  // 单独成行的工具（MCP 截图等）：图画在它的结果下面
  on('ui.render', { component: 'ToolResult' }, async ($, e, next) => {
    const base = await next(e)
    if (e.surface !== 'terminal' || e.props.isErrored) return base
    const items = picsOf(e.props.tool, undefined, e.props.output).map((pic, i) => ({
      key: `${e.props.tool_use_id}-${i}`,
      pic,
    }))
    return withPics($, e, base, items)
  })
}
