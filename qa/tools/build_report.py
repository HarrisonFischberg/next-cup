#!/usr/bin/env python3
"""Builds the browsable QA report (one self-contained HTML file) from scores.json.

usage: python3 qa/tools/build_report.py [results-dir] [baseline-dir] [out.html]
Fixture images are embedded as small JPEGs. Only synthetic test data and redacted run
metadata go in: no keys, no request headers.
"""
import base64
import hashlib
import html
import io
import json
import subprocess
import sys
from datetime import date
from pathlib import Path

from PIL import Image

QA = Path(__file__).resolve().parents[1]
results = Path(sys.argv[1]) if len(sys.argv) > 1 else QA / "results"
baseline = Path(sys.argv[2]) if len(sys.argv) > 2 else QA / "results" / "baseline"
out = Path(sys.argv[3]) if len(sys.argv) > 3 else QA / "report" / "index.html"
meta = json.loads((QA / "report" / "meta.json").read_text())

scores = json.loads((results / "scores.json").read_text())
base = json.loads((baseline / "scores.json").read_text()) if (baseline / "scores.json").exists() else None
manifest_bytes = (QA / "fixtures" / "manifest.json").read_bytes()
manifest = json.loads(manifest_bytes)
fx = {f["id"]: f for f in manifest["fixtures"]}
FIELDS = manifest["fields"]
commit = subprocess.run(["git", "-C", str(QA), "rev-parse", "--short", "HEAD"],
                        capture_output=True, text=True).stdout.strip()


def thumb(path):
    img = Image.open(path).convert("RGB")
    img.thumbnail((420, 420))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=70)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def pct(w):
    return "n/a" if not w else f"{w[0]*100:.0f}% <span class=ci>({w[1]*100:.0f}–{w[2]*100:.0f})</span>"


def show(v):
    if isinstance(v, list):
        return ", ".join(map(str, v))
    if isinstance(v, bool):
        return "yes" if v else "no"
    if v in (0, 0.0) and not isinstance(v, bool):
        return ""
    return str(v)


def summary_table(s, title):
    rows = []
    for prov, d in s.items():
        o = d["overall"]
        rows.append(f"<tr><th>{prov}</th><td>{pct(o['precision'])}</td><td>{pct(o['recall'])}</td>"
                    f"<td>{pct(o['invented_rate'])}</td><td>{pct(o['abstain_ok'])}</td><td>{pct(o['coverage'])}</td></tr>")
    return (f"<h3>{title}</h3><table><tr><th></th><th>Precision</th><th>Recall</th><th>Invented (of empty)</th>"
            f"<th>Correct unknown</th><th>Auto-fill coverage</th></tr>{''.join(rows)}</table>")


def field_table(s):
    provs = list(s)
    head = "".join(f"<th colspan=3>{p}</th>" for p in provs)
    sub = "".join("<th>Precision</th><th>Recall</th><th>Invented</th>" for _ in provs)
    rows = []
    for f in FIELDS:
        cells = ""
        for p in provs:
            d = s[p]["fields"].get(f)
            cells += (f"<td>{pct(d['precision'])}</td><td>{pct(d['recall'])}</td><td>{pct(d['invented_rate'])}</td>"
                      if d else "<td colspan=3>n/a</td>")
        rows.append(f"<tr><th>{f}</th>{cells}</tr>")
    return f"<table class=wide><tr><th></th>{head}</tr><tr><th>Field</th>{sub}</tr>{''.join(rows)}</table>"


def cards():
    by_fixture = {}
    for r in scores["rows"]:
        by_fixture.setdefault(r["fixture"], {})[r["provider"]] = r
    out = []
    for fid in sorted(by_fixture, key=lambda i: (fx[i]["parent"], i)):
        f = fx[fid]
        runs = by_fixture[fid]
        provs = sorted(runs)
        sev = "blocker" if any(r["blockers"] for r in runs.values()) else (
            "error" if any(v in ("wrong", "invented", "failed") for r in runs.values() for v in r["results"].values())
            else ("miss" if any(v == "missed" for r in runs.values() for v in r["results"].values()) else "clean"))
        cats = sorted({v for r in runs.values() for v in r["results"].values()})
        bad_fields = sorted({k for r in runs.values() for k, v in r["results"].items() if v not in ("correct", "abstain-ok")})
        head = "".join(f"<th>{p}</th>" for p in provs)
        rows = []
        for field in FIELDS:
            want = f.get("accept", {}).get(field) or f["expect"][field]
            if field in f.get("ignore", []):
                want_s = "<i>not scored</i>"
            elif isinstance(want, list) and want and isinstance(want[0], list):
                want_s = " | ".join(html.escape(show(w)) for w in want)
            elif isinstance(want, list) and field != "flavorNotes":
                want_s = " | ".join(html.escape(show(w)) or "∅" for w in want)
            else:
                want_s = html.escape(show(want)) or "∅"
            tds = ""
            for p in provs:
                r = runs[p]
                res = r["results"].get(field, "n/a")
                val = html.escape(show((r.get("fields") or {}).get(field, "")))
                tds += f"<td class='o-{res}' title='{res}'>{val or '∅'}</td>"
            rows.append(f"<tr data-field='{field}'><th>{field}</th><td class=exp>{want_s}</td>{tds}</tr>")
        meta_rows = ""
        for p in provs:
            r = runs[p]
            bits = [f"{r.get('model','')}", f"{r.get('ms','?')} ms", f"image attached: {'yes' if r.get('imageAttached') else 'no'}"]
            if r.get("messageID"):
                bits.append(f"request {html.escape(r['messageID'])}")
            if r.get("estUSD"):
                bits.append(f"${r['estUSD']:.4f} ({r.get('inputTokens')} in / {r.get('outputTokens')} out)")
            if r.get("status") != "ok":
                bits.append(f"<b>{html.escape(r.get('status',''))}: {html.escape(r.get('error',''))} {html.escape(r.get('cause',''))}</b>")
            for b in r["blockers"]:
                bits.append(f"<span class=blk>RELEASE BLOCKER: {html.escape(b)}</span>")
            meta_rows += f"<div class=run><b>{p}</b> · " + " · ".join(bits) + "</div>"
            if r.get("ocr") is not None:
                meta_rows += f"<details><summary>Apple Vision OCR text (evidence)</summary><pre>{html.escape(chr(10).join(r['ocr']))}</pre></details>"
        out.append(f"""<article class=card data-sev='{sev}' data-providers='{" ".join(provs)}'
 data-cats='{" ".join(cats)}' data-bad='{" ".join(bad_fields)}' data-source='{f["source"]}' data-split='{f["split"]}'>
<header><h3>{fid}</h3><span class='tag sev-{sev}'>{sev}</span><span class=tag>{f['source']}</span>
<span class=tag>{f['split']}</span><span class=tag>{f['condition']}</span>{''.join(f"<span class=tag>{t}</span>" for t in f['tags'])}</header>
<div class=body><img loading=lazy alt='Fixture {fid}' src='{thumb(QA / "fixtures" / f["file"])}'>
<div class=cmp><table><tr><th>Field</th><th>Expected</th>{head}</tr>{''.join(rows)}</table>{meta_rows}</div></div></article>""")
    return "\n".join(out)


def ops_table():
    rows = []
    for p, o in scores["ops"].items():
        rows.append(f"<tr><th>{p}</th><td>{o['model']}</td><td>{o['runs']}</td><td>{o['ok']}</td><td>{o['errors']}</td>"
                    f"<td>{o['p50_ms']}</td><td>{o['p90_ms']}</td><td>{o['input_tokens']} / {o['output_tokens']}</td>"
                    f"<td>${o['est_usd']:.3f}</td><td>{o['blockers']}</td></tr>")
    return ("<table><tr><th></th><th>Model</th><th>Runs</th><th>OK</th><th>Errors</th><th>p50 ms</th><th>p90 ms</th>"
            f"<th>Tokens in / out</th><th>Est. cost</th><th>Blockers</th></tr>{''.join(rows)}</table>")


def repeat_table():
    if not scores.get("repeat"):
        return "<p>No repeated runs in this result set.</p>"
    rows = []
    for p, items in scores["repeat"].items():
        stable = sum(i["distinct"] == 1 for i in items)
        rows.append(f"<tr><th>{p}</th><td>{len(items)}</td><td>{stable}</td><td>{', '.join(i['fixture'] + ' (' + str(i['distinct']) + ' variants)' for i in items if i['distinct'] > 1) or '–'}</td></tr>")
    return f"<table><tr><th></th><th>Fixtures repeated</th><th>Identical every run</th><th>Varied</th></tr>{''.join(rows)}</table>"


def listing(items, cls=""):
    return f"<ul class='{cls}'>" + "".join(f"<li>{i}</li>" for i in items) + "</ul>"


CSS = """
:root{--bg:#f6f7f9;--panel:#fff;--ink:#16202c;--muted:#5a6878;--line:#d9dee5;--accent:#2457c5;
--ok:#1f7a4d;--okbg:#e3f4ea;--bad:#b42335;--badbg:#fbe5e8;--miss:#4a5a6e;--missbg:#e9edf2;--blk:#8a1023}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){--bg:#0f141a;--panel:#18202a;--ink:#e7ecf2;--muted:#9aa8b8;
--line:#2c3744;--accent:#7aa2ff;--ok:#6fd49b;--okbg:#173a28;--bad:#ff8a98;--badbg:#45161d;--miss:#b6c2d0;--missbg:#232d39;--blk:#ff9aa8;color-scheme:dark}}
:root[data-theme=dark]{--bg:#0f141a;--panel:#18202a;--ink:#e7ecf2;--muted:#9aa8b8;--line:#2c3744;--accent:#7aa2ff;
--ok:#6fd49b;--okbg:#173a28;--bad:#ff8a98;--badbg:#45161d;--miss:#b6c2d0;--missbg:#232d39;--blk:#ff9aa8;color-scheme:dark}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 "IBM Plex Sans",-apple-system,system-ui,sans-serif}
main{max-width:1200px;margin:0 auto;padding-block:24px 80px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
h1,h2,h3{text-wrap:balance}td,.stat b,.run{font-variant-numeric:tabular-nums}pre,code,.ci{font-family:"IBM Plex Mono",ui-monospace,monospace}
:focus-visible{outline:2px solid var(--accent);outline-offset:2px}h1{font-size:28px;margin:0 0 4px}h2{margin-top:40px;border-bottom:1px solid var(--line);padding-bottom:6px}
.sub{color:var(--muted)}table{border-collapse:collapse;margin:8px 0 16px;background:var(--panel);font-size:13px}
table{display:block;max-width:100%;overflow-x:auto}
th,td{border:1px solid var(--line);padding:5px 8px;text-align:left;vertical-align:top}.wide{width:100%}.ci{color:var(--muted);font-size:11px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px}.stat{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:12px}
.stat b{display:block;font-size:24px}.verdict{background:var(--panel);border-left:4px solid var(--accent);padding:12px 16px;border-radius:6px}
.filters{position:sticky;top:env(safe-area-inset-top,0px);background:var(--bg);padding:10px 0;z-index:2;display:flex;flex-wrap:wrap;gap:8px;border-bottom:1px solid var(--line)}
select,button{font:inherit;padding:6px 10px;border-radius:8px;border:1px solid var(--line);background:var(--panel);color:var(--ink);min-height:36px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:12px;margin:14px 0;padding:12px}
.card header{display:flex;flex-wrap:wrap;gap:6px;align-items:center}.card h3{margin:0 8px 0 0}
.tag{font-size:11px;border:1px solid var(--line);border-radius:99px;padding:1px 8px;color:var(--muted)}
.sev-blocker{background:var(--badbg);color:var(--blk);border-color:var(--bad)}.sev-error{color:var(--bad)}.sev-clean{color:var(--ok)}
.body{display:flex;gap:14px;flex-wrap:wrap;margin-top:10px}.body img{width:240px;max-width:100%;height:auto;border-radius:8px;border:1px solid var(--line);cursor:zoom-in}
.body img.big{width:100%;max-width:640px}.cmp{flex:1;min-width:300px;overflow-x:auto}
.o-correct{background:var(--okbg)}.o-wrong,.o-invented,.o-failed{background:var(--badbg);color:var(--bad);font-weight:600}
.o-missed{background:var(--missbg);color:var(--miss);font-style:italic}.exp{color:var(--muted)}
.run{font-size:12px;color:var(--muted);margin:4px 0}.blk{color:var(--blk);font-weight:700}pre{white-space:pre-wrap;font-size:12px}
.legend span{display:inline-block;padding:1px 8px;margin-right:6px;border-radius:4px;font-size:12px}
code{background:var(--missbg);padding:1px 4px;border-radius:4px}.cmd{background:var(--panel);border:1px solid var(--line);padding:10px;border-radius:8px;overflow-x:auto}
@media (max-width:600px){.body img{width:100%}}
"""

JS = """
const q=s=>document.querySelector(s);
function apply(){const p=q('#fp').value,f=q('#ff').value,s=q('#fs').value,c=q('#fc').value,src=q('#fsrc').value;let n=0;
document.querySelectorAll('.card').forEach(el=>{const ok=(!p||el.dataset.providers.split(' ').includes(p))&&(!f||el.dataset.bad.split(' ').includes(f))
&&(!s||el.dataset.sev===s)&&(!c||el.dataset.cats.split(' ').includes(c))&&(!src||el.dataset.source===src||el.dataset.split===src);el.hidden=!ok;if(ok)n++;
el.querySelectorAll('tr[data-field]').forEach(tr=>tr.style.outline=f&&tr.dataset.field===f?'2px solid var(--accent)':'');});
q('#count').textContent=n+' fixtures';try{localStorage.setItem('qa.filters',JSON.stringify([p,f,s,c,src]))}catch(e){}}
document.querySelectorAll('.filters select').forEach(s=>s.addEventListener('change',apply));
q('#reset').addEventListener('click',()=>{document.querySelectorAll('.filters select').forEach(s=>s.value='');apply()});
document.querySelectorAll('.body img').forEach(i=>i.addEventListener('click',()=>i.classList.toggle('big')));
try{const v=JSON.parse(localStorage.getItem('qa.filters')||'null');if(v)['#fp','#ff','#fs','#fc','#fsrc'].forEach((id,i)=>q(id).value=v[i]||'')}catch(e){}
apply();
"""


def opts(values):
    return "".join(f"<option value='{v}'>{v}</option>" for v in values)


provs = sorted(scores["overall"])
HEAD = f"""<title>Next Cup Bean QA</title><meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono&family=IBM+Plex+Sans:wght@400;600&display=swap">
<style>{CSS}</style>"""
page = f"""<main>
<h1>Next Cup bean capture QA</h1>
<p class=sub>Commit {commit} · prompt v{meta['prompt_version']} · fixtures v{manifest['version']} ({hashlib.sha256(manifest_bytes).hexdigest()[:10]}) ·
{meta['device']} · Anthropic model {scores['ops'].get('anthropic', {}).get('model', 'not run')} · {date.today().isoformat()}</p>

<div class=verdict><h2 style='margin-top:0;border:0'>Release recommendation</h2>{meta['recommendation']}</div>

<h2>Counts</h2><div class=grid>{''.join(f"<div class=stat><span class=sub>{k}</span><b>{v}</b></div>" for k, v in meta['counts'].items())}</div>

<h2>Accuracy (synthetic fixtures, after fixes)</h2>
<p class=sub>Deterministic comparison against labels that are exact by construction. 95% Wilson intervals in brackets. Synthetic labels only: there are no real bag photos in this set yet, so these numbers say nothing about real-world accuracy.</p>
{summary_table(scores['overall'], 'All fixtures')}
{summary_table(scores['by_split'].get('heldout', {}), 'Held-out split only')}
{summary_table(base['overall'], 'Before fixes (baseline, same fixtures)') if base else ''}
<h3>Per field</h3>{field_table(scores['overall'])}
<h3>By image condition</h3>{''.join(summary_table(v, k) for k, v in scores['by_condition'].items())}
<h3>Operations</h3>{ops_table()}<h3>Repeat runs (nondeterminism)</h3>{repeat_table()}

<h2>Provider and device matrix</h2><table><tr><th>Scenario</th><th>Status</th><th>Evidence</th></tr>
{''.join(f"<tr><th>{html.escape(r[0])}</th><td>{r[1]}</td><td>{r[2]}</td></tr>" for r in meta['matrix'])}</table>

<h2>Confirmed defects</h2><table><tr><th>ID</th><th>Severity</th><th>Defect</th><th>Status</th><th>Regression test</th></tr>
{''.join(f"<tr><th>{d[0]}</th><td>{d[1]}</td><td>{d[2]}</td><td>{d[3]}</td><td>{d[4]}</td></tr>" for d in meta['defects'])}</table>

<h2>Implemented</h2>{listing(meta['implemented'])}
<h2>Rerun</h2>{''.join(f"<p>{html.escape(c[0])}</p><pre class=cmd>{html.escape(c[1])}</pre>" for c in meta['commands'])}
<h2>Still open</h2>{listing(meta['open'])}

<h2>Fixtures</h2>
<p class=legend><span class=o-correct>correct</span><span class=o-missed>missed (left blank)</span><span class=o-wrong>wrong or invented</span> ∅ = empty. Click an image to enlarge.</p>
<div class=filters role=group aria-label='Filter fixtures'>
<select id=fp aria-label=Provider><option value=''>All providers</option>{opts(provs)}</select>
<select id=ff aria-label=Field><option value=''>Any field with an error</option>{opts(FIELDS)}</select>
<select id=fs aria-label=Severity><option value=''>Any severity</option>{opts(['blocker','error','miss','clean'])}</select>
<select id=fc aria-label='Failure category'><option value=''>Any category</option>{opts(['invented','wrong','missed','failed','abstain-ok','correct'])}</select>
<select id=fsrc aria-label='Source or split'><option value=''>All sources</option>{opts(['synthetic','real','dev','heldout'])}</select>
<button id=reset type=button>Reset</button><span id=count class=sub></span></div>
{cards()}
</main><script>{JS}</script>"""
out.parent.mkdir(parents=True, exist_ok=True)
# The local copy is a full document; the Artifact copy is body content (the host adds the skeleton).
out.write_text(f"<!doctype html><html lang=en><head><meta charset=utf-8>"
               f"<meta name=viewport content='width=device-width,initial-scale=1,viewport-fit=cover'>"
               f"{HEAD}</head><body>{page}</body></html>")
out.with_name("artifact.html").write_text(HEAD + page)
print(f"wrote {out} ({out.stat().st_size // 1024} KB)")
