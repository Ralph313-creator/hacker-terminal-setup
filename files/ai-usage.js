// Prints the last known plan usage of each AI coding agent, for the shell prompt.
//   Claude Code : ~/.cache/ai-usage/claude.json (written by ~/.claude/statusline.js)
//   Codex CLI   : rate_limits in the newest ~/.codex/sessions/**/rollout-*.jsonl
// Output: "<level>|<text>", e.g. "warn|Claude 5h 72% 7d 40% │ GPT 5h 12%"
//   level = ok | warn (any window >= 70%) | hot (any window >= 90%), used by the prompt to pick a color.
// Prints nothing if no agent has data.
const fs = require('fs');
const os = require('os');
const path = require('path');

function toMs(t) {
  if (t == null) return null;
  if (typeof t === 'number') return t < 1e12 ? t * 1000 : t;
  const v = Date.parse(t);
  return isNaN(v) ? null : v;
}

function windowLabel(minutes, fallback) {
  if (minutes === 300) return '5h';
  if (minutes === 10080) return '7d';
  if (minutes) return minutes % 1440 === 0 ? `${minutes / 1440}d` : `${Math.round(minutes / 60)}h`;
  return fallback;
}

// Each agent returns [{label, pct}] for windows that haven't reset yet
function claude() {
  try {
    const f = path.join(os.homedir(), '.cache', 'ai-usage', 'claude.json');
    const { rate_limits: rl } = JSON.parse(fs.readFileSync(f, 'utf8'));
    const out = [];
    for (const [key, label] of [['five_hour', '5h'], ['seven_day', '7d']]) {
      const w = rl?.[key];
      const pct = w?.used_percentage;
      if (typeof pct !== 'number') continue;
      const reset = toMs(w.resets_at);
      if (reset && reset < Date.now()) continue;
      out.push({ label, pct: Math.round(pct) });
    }
    return out;
  } catch { return []; }
}

function newestRollouts(root, max) {
  // sessions/YYYY/MM/DD/rollout-*.jsonl: walk newest dates first
  const found = [];
  const desc = (dir) => { try { return fs.readdirSync(dir).sort().reverse(); } catch { return []; } };
  for (const y of desc(root)) for (const m of desc(path.join(root, y))) for (const d of desc(path.join(root, y, m))) {
    const dir = path.join(root, y, m, d);
    const files = desc(dir).filter((f) => f.startsWith('rollout-') && f.endsWith('.jsonl'))
      .map((f) => path.join(dir, f))
      .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
    found.push(...files);
    if (found.length >= max) return found.slice(0, max);
  }
  return found;
}

function readTail(file, bytes) {
  const fd = fs.openSync(file, 'r');
  try {
    const size = fs.fstatSync(fd).size;
    const len = Math.min(size, bytes);
    const buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, size - len);
    return buf.toString('utf8');
  } finally { fs.closeSync(fd); }
}

function codex() {
  const root = path.join(process.env.CODEX_HOME || path.join(os.homedir(), '.codex'), 'sessions');
  try {
    for (const file of newestRollouts(root, 5)) {
      // Session logs can be huge; the latest rate limits are near the end
      const lines = readTail(file, 512 * 1024).split('\n').reverse();
      for (const line of lines) {
        if (!line.includes('"rate_limits"')) continue;
        let ev;
        try { ev = JSON.parse(line); } catch { continue; }
        const rl = ev.payload?.rate_limits || ev.rate_limits;
        if (!rl) continue;
        const evTime = toMs(ev.timestamp) || fs.statSync(file).mtimeMs;
        const out = [];
        for (const [key, fallback] of [['primary', '5h'], ['secondary', '7d']]) {
          const w = rl[key];
          if (typeof w?.used_percent !== 'number') continue;
          const reset = toMs(w.resets_at) ?? (w.resets_in_seconds != null ? evTime + w.resets_in_seconds * 1000 : null);
          if (reset && reset < Date.now()) continue;
          out.push({ label: windowLabel(w.window_minutes, fallback), pct: Math.round(w.used_percent) });
        }
        return out;
      }
    }
  } catch {}
  return [];
}

const agents = [['Claude', claude()], ['GPT', codex()]].filter(([, wins]) => wins.length);
if (agents.length) {
  const max = Math.max(...agents.flatMap(([, wins]) => wins.map((w) => w.pct)));
  const level = max >= 90 ? 'hot' : max >= 70 ? 'warn' : 'ok';
  const text = agents.map(([name, wins]) => name + ' ' + wins.map((w) => `${w.label} ${w.pct}%`).join(' ')).join(' │ ');
  process.stdout.write(`${level}|${text}`);
}
