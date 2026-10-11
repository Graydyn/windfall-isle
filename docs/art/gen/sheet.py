"""Build docs/art/review/index.html (grouped gallery with prompts) and a PNG contact sheet."""
import glob, html, json, os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import manifest as M

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
log = {}
for line in open(os.path.join(ROOT, "docs/art/gen/log.jsonl")):
    e = json.loads(line)
    if e.get("ok"):
        log[e["out"]] = e
files = sorted(glob.glob("game/art/**/*.png", recursive=True), key=lambda p: (os.path.dirname(p), p))

# contact sheet
cell = 150
cols = 10
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * cell, rows * (cell + 14)), (70, 100, 150, 255))
d = ImageDraw.Draw(sheet)
for i, p in enumerate(files):
    im = Image.open(p).convert("RGBA")
    im.thumbnail((cell - 8, cell - 8))
    x, y = (i % cols) * cell, (i // cols) * (cell + 14)
    sheet.alpha_composite(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2))
    d.text((x + 3, y + cell), os.path.basename(p)[:24], fill=(255, 255, 255, 255))
sheet.save(sys.argv[1] if len(sys.argv) > 1 else "/tmp/sheet.png")

# html gallery
groups = {}
for p in files:
    groups.setdefault(os.path.dirname(p), []).append(p)
out = ['<!doctype html><meta charset="utf-8"><title>Windfall Art Review</title><style>',
       'body{font:14px system-ui;background:#1d2330;color:#e8e8ee;margin:16px}h2{margin-top:32px}',
       '.g{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:12px}',
       '.c{background:#2a3242;border-radius:8px;padding:8px}.c img{display:block;margin:auto;max-width:100%;max-height:220px;image-rendering:auto;',
       'background:repeating-conic-gradient(#556 0 25%,#445 0 50%) 0 0/16px 16px;padding:6px;border-radius:4px}',
       '.n{font-weight:600;margin-top:6px}.s{color:#9aa;font-size:12px}details{font-size:12px;color:#bbc}</style>',
       f'<h1>Windfall Isles art review</h1><p>{len(files)} images from jig. Checkerboard = transparency. Expand "prompt" for the exact text sent.</p>',
       '<p>Style v2 (bright cartoon), 2026-10-09. Prompts and what was left out: <a href="../style-v2-prompts.md">style-v2-prompts.md</a>. Crew portraits are from v1.</p>']
for g, ps in groups.items():
    out.append(f"<h2>{html.escape(g)}</h2><div class=g>")
    for p in ps:
        im = Image.open(p)
        e = log.get(p, {})
        prompt = e.get("prompt") or ""
        out.append(f'<div class=c><img src="../../../{p}"><div class=n>{html.escape(os.path.basename(p))}</div>'
                   f'<div class=s>{im.width}×{im.height} · job {html.escape(str(e.get("job_id", ""))[:8])}</div>'
                   f'<details><summary>prompt</summary>{html.escape(prompt)}</details></div>')
    out.append("</div>")
open(os.path.join(ROOT, "docs/art/review/index.html"), "w").write("\n".join(out))
print(len(files), "images")
