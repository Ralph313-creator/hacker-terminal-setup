// Claude Code status line: context window, plan usage limits, session cost.
// Claude Code pipes session JSON on stdin and shows whatever this prints.
// Also saves the plan limits to ~/.cache/ai-usage/claude.json for the shell prompt's usage segment.
const fs = require('fs');
const os = require('os');
const path = require('path');

let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let d = {};
  try { d = JSON.parse(raw); } catch {}
  saveLimits(d.rate_limits);
  process.stdout.write(render(d));
});

function saveLimits(rl) {
  if (!rl || (!rl.five_hour && !rl.seven_day)) return;
  try {
    const dir = path.join(os.homedir(), '.cache', 'ai-usage');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'claude.json'), JSON.stringify({ updated: Date.now(), rate_limits: rl }));
  } catch {}
}

const rgb = (r, g, b) => (s) => `\x1b[38;2;${r};${g};${b}m${s}\x1b[0m`;
const bright = rgb(57, 255, 20);
const green = rgb(0, 200, 50);
const dim = rgb(47, 90, 56);
const warn = rgb(228, 255, 122);
const hot = rgb(255, 85, 85);
const sep = dim(' │ ');

function level(pct) {
  if (pct >= 90) return hot;
  if (pct >= 70) return warn;
  return bright;
}

function bar(pct, width = 10) {
  const filled = Math.round((Math.min(Math.max(pct, 0), 100) / 100) * width);
  return level(pct)('█'.repeat(filled)) + dim('░'.repeat(width - filled));
}

function resetIn(resetsAt) {
  if (resetsAt == null) return '';
  const t = typeof resetsAt === 'number' ? (resetsAt < 1e12 ? resetsAt * 1000 : resetsAt) : Date.parse(resetsAt);
  const mins = Math.round((t - Date.now()) / 60000);
  if (!isFinite(mins) || mins <= 0) return '';
  if (mins < 60) return `${mins}m`;
  if (mins < 48 * 60) return `${Math.floor(mins / 60)}h${String(mins % 60).padStart(2, '0')}m`;
  return `${Math.round(mins / 1440)}d`;
}

function pctOf(x) {
  if (x == null) return null;
  const v = typeof x === 'object' ? (x.used_percentage ?? x.utilization ?? x.percent) : x;
  return typeof v === 'number' ? Math.round(v) : null;
}

function render(d) {
  const parts = [];

  parts.push(bright('Super intelligent'));

  const cw = d.context_window || {};
  let ctx = cw.used_percentage;
  if (ctx == null && cw.current_usage && cw.context_window_size) {
    const u = cw.current_usage;
    const used = (u.input_tokens || 0) + (u.cache_creation_input_tokens || 0) + (u.cache_read_input_tokens || 0);
    ctx = (used / cw.context_window_size) * 100;
  }
  if (ctx != null) parts.push(`${green('ctx')} ${bar(ctx)} ${level(ctx)(Math.round(ctx) + '%')}`);

  const rl = d.rate_limits || {};
  for (const [key, label] of [['five_hour', '5h'], ['seven_day', '7d']]) {
    const p = pctOf(rl[key]);
    if (p == null) continue;
    const r = resetIn(rl[key]?.resets_at);
    parts.push(`${green(label)} ${bar(p, 8)} ${level(p)(p + '%')}${r ? dim(' ↻' + r) : ''}`);
  }

  const cost = d.cost?.total_cost_usd;
  if (typeof cost === 'number') parts.push(green('$') + bright(cost.toFixed(2)));

  return parts.join(sep);
}
