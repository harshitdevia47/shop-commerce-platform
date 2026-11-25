/**
 * Tiny HTML templating for the admin site: every interpolated value is escaped unless it is
 * already `Html` (built by `html` itself or by `raw` for trusted markup).
 */
export class Html {
  constructor(readonly value: string) {}
  toString(): string {
    return this.value;
  }
}

const escapeText = (text: string) =>
  text.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

type Value = Html | string | number | boolean | null | undefined | Value[];

function render(value: Value): string {
  if (value === null || value === undefined || value === false) return '';
  if (Array.isArray(value)) return value.map(render).join('');
  if (value instanceof Html) return value.value;
  return escapeText(String(value));
}

export function html(strings: TemplateStringsArray, ...values: Value[]): Html {
  return new Html(strings.reduce((out, part, i) => out + part + (i < values.length ? render(values[i]!) : ''), ''));
}

export const raw = (markup: string) => new Html(markup);

const STYLES = `
:root { color-scheme: light dark; --bg: #f6f7f9; --card: #fff; --text: #1d2330; --muted: #5d6675; --line: #dfe3ea;
  --accent: #1b5e20; --accent-text: #fff; --bad: #b3261e; --warn: #8a5a00; --ok: #1b6e2a; --info: #2457a6; }
@media (prefers-color-scheme: dark) { :root { --bg: #111418; --card: #1a1f26; --text: #e7eaf0; --muted: #a2aab7;
  --line: #2c333d; --accent: #66bb6a; --accent-text: #0b1a0c; --bad: #f2b8b5; --warn: #f0c36b; --ok: #8fd19e; --info: #a9c7ff; } }
* { box-sizing: border-box; }
body { margin: 0; font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", sans-serif; background: var(--bg); color: var(--text); }
header { background: var(--card); border-bottom: 1px solid var(--line); }
header .bar, main { max-width: 920px; margin: 0 auto; padding: 12px 16px; }
header .bar { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
header a.brand { font-weight: 700; color: var(--text); text-decoration: none; }
main { padding-bottom: 48px; }
h1 { font-size: 1.4rem; margin: 16px 0 4px; } h2 { font-size: 1.1rem; margin: 24px 0 8px; }
a { color: var(--info); }
.muted { color: var(--muted); } .small { font-size: .875rem; }
.card { background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 16px; margin: 12px 0; }
.tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 8px; margin: 12px 0; }
.tile { background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 12px; }
.tile b { display: block; font-size: 1.6rem; line-height: 1.2; }
.badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: .8rem; font-weight: 600; border: 1px solid currentColor; white-space: nowrap; }
.s-overdue, .s-paused { color: var(--bad); } .s-due { color: var(--warn); } .s-due_soon { color: var(--info); }
.s-paid { color: var(--ok); } .s-not_set_up { color: var(--muted); }
.list { list-style: none; margin: 0; padding: 0; }
.list li a { display: flex; justify-content: space-between; gap: 12px; padding: 12px 0; border-bottom: 1px solid var(--line); color: var(--text); text-decoration: none; }
.list li:last-child a { border-bottom: 0; }
.row { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
dl { display: grid; grid-template-columns: max-content 1fr; gap: 4px 16px; margin: 0; } dt { color: var(--muted); } dd { margin: 0; }
form.stack { display: grid; gap: 10px; max-width: 420px; }
label { display: grid; gap: 4px; font-size: .9rem; color: var(--muted); }
input, textarea { font: inherit; color: var(--text); background: var(--bg); border: 1px solid var(--line); border-radius: 8px; padding: 10px 12px; width: 100%; }
button, .button { font: inherit; font-weight: 600; border-radius: 8px; padding: 10px 14px; border: 1px solid var(--line); background: var(--card); color: var(--text); cursor: pointer; text-decoration: none; display: inline-block; }
button.primary, .button.primary { background: var(--accent); color: var(--accent-text); border-color: var(--accent); }
button.danger { color: var(--bad); border-color: var(--bad); }
.notice { border-left: 4px solid var(--ok); } .notice.error { border-left-color: var(--bad); }
table { width: 100%; border-collapse: collapse; font-size: .95rem; } th, td { text-align: left; padding: 8px 6px; border-bottom: 1px solid var(--line); }
th { color: var(--muted); font-weight: 600; }
.check { display: flex; gap: 8px; align-items: center; padding: 4px 0; }
`;

/** Full page. `admin` = signed-in email (shows the log-out button). */
export function page(title: string, body: Html, opts: { admin?: string } = {}): string {
  return html`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>${title} · Shop apps admin</title>
<style>${raw(STYLES)}</style>
</head>
<body>
<header><div class="bar">
  <a class="brand" href="/">Shop apps admin</a>
  ${opts.admin ? html`<form method="post" action="/logout"><span class="muted small">${opts.admin}</span> <button type="submit">Log out</button></form>` : ''}
</div></header>
<main>
${body}
</main>
</body>
</html>`.value;
}

/** Security headers for every admin page: nothing external, no framing, never cached. */
export const PAGE_HEADERS: Record<string, string> = {
  'content-type': 'text/html; charset=utf-8',
  'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data:; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
  'cache-control': 'no-store',
  // same-origin (not no-referrer): with no-referrer browsers send "Origin: null" on form posts.
  'referrer-policy': 'same-origin',
  'x-content-type-options': 'nosniff',
};
