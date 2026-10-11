"""Run one manifest entry through jig (foreground) and log the result.

usage: python3 docs/art/gen/run.py <key> [--overwrite]
       python3 docs/art/gen/run.py --list   (keys with no result for this manifest VERSION, in order)
       python3 docs/art/gen/run.py --wait <key>   (collect a background that outlived its timeout)
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import manifest as M  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
LOG = os.path.join(ROOT, "docs/art/gen/log.jsonl")


def log_entries():
    if not os.path.exists(LOG):
        return []
    with open(LOG) as f:
        return [json.loads(line) for line in f if line.strip()]


def job_for(key, pending=False):
    """Latest job for `key` made under the current manifest VERSION."""
    for e in reversed(log_entries()):
        if e["key"] == key and e.get("v") == M.VERSION and (e.get("ok") or (pending and e.get("job_id"))):
            return e["job_id"]
    return None


def out_of(key):
    for table in (M.A, M.EDITS, M.BACKGROUNDS, M.STRIPS):
        if key in table:
            return table[key][0]
    raise KeyError(key)


def all_keys():
    return M.REQUIRED_ORDER + list(M.BACKGROUNDS) + list(M.STRIPS) + M.NICE_ORDER


def main():
    if sys.argv[1] == "--list":
        for k in all_keys():
            if not job_for(k):
                print(k)
        return
    key = sys.argv[2] if sys.argv[1] == "--wait" else sys.argv[1]
    overwrite = "--overwrite" in sys.argv
    out = out_of(key)
    os.makedirs(os.path.join(ROOT, os.path.dirname(out)), exist_ok=True)
    if sys.argv[1] == "--wait":
        cmd = ["jig", "wait", job_for(key, pending=True), "--out", out, "--timeout", "540", "--overwrite"]
    elif key in M.BACKGROUNDS or key in M.STRIPS:
        # Match the pilot sprites so the backdrop sits with the art on it.
        styles = [j for j in (job_for(k) for k in M.PILOT) if j]
        if key in M.STRIPS:
            _, size, desc = M.STRIPS[key]
        else:
            size, desc = M.BG_SIZE, M.BG_STYLE + " " + M.BACKGROUNDS[key][1]
        cmd = ["jig", "background", "--description", desc,
               "--size", size, "--style", "painted", "--out", out, "--timeout", "540"]
        for j in styles:
            cmd += ["--style-job", j]
    elif key in M.A:
        _, size, subject, theme, spec_name = M.A[key]
        spec = dict(M.SPECS[spec_name], canvas_size=size)
        cmd = ["jig", "generate", "--subject", subject, "--theme", M.THEMES[theme],
               "--spec", json.dumps(spec), "--out", out, "--timeout", "570"]
    else:
        _, source, instruction = M.EDITS[key]
        src_job = job_for(source)
        if not src_job:
            sys.exit(f"no finished job for source '{source}' yet")
        src_out = out_of(source) if source in M.A else None
        size = M.A[source][1] if source in M.A else [104, 104]
        spec_name = M.A[source][4] if source in M.A else "sprite"
        spec = dict(M.SPECS[spec_name], canvas_size=size)
        cmd = ["jig", "edit", src_job, "--instruction", instruction,
               "--spec", json.dumps(spec), "--out", out, "--timeout", "570"]
    if overwrite:
        cmd.append("--overwrite")
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    try:
        result = json.loads(proc.stdout)
    except json.JSONDecodeError:
        result = {"error": {"kind": "unparsed", "message": proc.stdout[-500:] + proc.stderr[-500:]}}
    err = result.get("error")
    entry = {
        "key": key, "v": M.VERSION, "out": out, "exit": proc.returncode, "ok": proc.returncode == 0,
        "job_id": result.get("id") or (err or {}).get("job_id"),
        "prompt": result.get("prompt"), "seed": result.get("seed"),
        "error": err,
    }
    with open(LOG, "a") as f:
        f.write(json.dumps(entry) + "\n")
    print(json.dumps({k: entry[k] for k in ("key", "exit", "job_id", "out")}))
    if err:
        print(json.dumps(err, indent=1)[:1500])


if __name__ == "__main__":
    main()
