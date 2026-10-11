"""Render manifest.py to docs/art/style-v2-prompts.md for human review."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import manifest as M  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
GROUPS = [
    ("Run board", "game/art/run/"),
    ("Regions: pegs, hazards, emblems", "game/art/regions/"),
    ("Gizmos and rarity frames", "game/art/gizmos/"),
    ("Buildings and islets", "game/art/buildings/"),
    ("Icons", "game/art/icons/"),
    ("UI", "game/art/ui/"),
]

out = [
    f"# Art prompts, style v{M.VERSION}: bright and cartoony",
    "",
    "Generated from [gen/manifest.py](gen/manifest.py) by `python3 docs/art/gen/prompts_doc.py`; edit the manifest, not this file.",
    "",
    "**Why v2:** v1 gave jig almost no style direction, so \"cozy salvage, wood and brass\" turned into brown, dark, semi-realistic art that looks muddy on screen. v2 puts one shared cartoon style in front of every prompt, and every subject names its own bright colours instead of raw wood or old brass. Keys and output paths are unchanged, so existing wiring picks up the new art.",
    "",
    "## Shared style (prepended to every sprite and icon)",
    "",
    f"> {M.STYLE}",
    "",
    "| Theme | Added after the shared style |",
    "|---|---|",
]
for name, text in M.THEMES.items():
    out.append(f"| {name} | {text.replace(M.STYLE, '').lstrip(', ') or text} |")
out += [
    "",
    "## Plan",
    "",
    f"1. **Pilot** ({', '.join(M.PILOT)}): generate these five first and review them before spending on the rest.",
    "2. **Everything else** in the tables below, then the edit-based variants.",
    "3. **Region backgrounds** last, passing the pilot jobs as `--style-job` so the backdrops match the sprites.",
    "",
    f"## Region backgrounds (`jig background`, {M.BG_SIZE}, painted)",
    "",
    "Each description is sent as the shared background brief followed by the region line.",
    "",
    f"> {M.BG_STYLE}",
    "",
    "| Key | Region line |",
    "|---|---|",
]
for k, (path, text) in M.BACKGROUNDS.items():
    out.append(f"| `{k}` | {text} |")
out += ["", "## Edge-to-edge strips (`jig background`, no shared background brief)", "", "| Key | Size | Description |", "|---|---|---|"]
for k, (path, size, text) in M.STRIPS.items():
    out.append(f"| `{k}` | {size} | {text} |")
for title, prefix in GROUPS:
    rows = [(k, v) for k, v in M.A.items() if v[0].startswith(prefix)]
    if not rows:
        continue
    out += ["", f"## {title}", "", "| Key | Size | Theme | Subject |", "|---|---|---|---|"]
    for k, (path, size, subject, theme, spec) in rows:
        out.append(f"| `{k}` | {size[0]}x{size[1]} | {theme} | {subject} |")
out += ["", "## Variants (`jig edit` of the base image)", "", "| Key | From | Instruction |", "|---|---|---|"]
for k, (path, src, instr) in M.EDITS.items():
    out.append(f"| `{k}` | `{src}` | {instr} |")
out += [
    "",
    "## Not in this batch",
    "",
    "- **Cloud sea, drift band, gyro field, magnet ring, wind and sleet columns:** v1 showed `jig generate` can't make soft translucent overlays or white-on-white clouds. The cloud sea is now painted into the bottom of each region background; the rest stay Godot shader or particle work.",
    "- **Crew portraits:** kept from v1; they already read well.",
    "- **App icon:** full-bleed, so it needs `jig background`; do it after the region-1 backdrop sets the look.",
    "",
    "## Wiring",
    "",
    "- **Barges** moved from `game/assets/sprites/` (100 px) to `game/art/run/barge*.png` (200 px); `_barge_visual()` scales to the catch width.",
    "- **Region backgrounds** are drawn by `Skyfield._build_background()` behind the board at 720x1280.",
    "",
]
open(os.path.join(ROOT, "docs/art/style-v2-prompts.md"), "w").write("\n".join(out))
print(len(M.A), "sprites,", len(M.EDITS), "edits,", len(M.BACKGROUNDS), "backgrounds")
