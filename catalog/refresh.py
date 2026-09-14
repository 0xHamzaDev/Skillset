#!/usr/bin/env python3
"""Refresh catalog.json: pull every skill's frontmatter from GitHub and keep the curated parts.

Run: python3 catalog/refresh.py
"""
import json, re, sys, urllib.request
from pathlib import Path

HERE = Path(__file__).parent
CATALOG = HERE / "catalog.json"


def frontmatter(text):
    m = re.match(r"^---\s*\n(.*?)\n---", text, re.S)
    if not m:
        return {}
    out, key, block = {}, None, None
    for line in m.group(1).splitlines():
        if block is not None and (line.startswith("  ") or line.strip() == ""):
            block.append(line.strip())
            continue
        if block is not None:
            out[key] = " ".join(x for x in block if x).strip()
            block = None
        km = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if not km:
            continue
        key, value = km.group(1), km.group(2).strip()
        if value in ("", ">", ">-", "|", "|-"):
            block = []
        else:
            out[key] = value.strip("\"'")
    if block is not None:
        out[key] = " ".join(x for x in block if x).strip()
    return out


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "skillset-catalog"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode()


def main():
    data = json.loads(CATALOG.read_text())
    failures = 0
    for skill in data["skills"]:
        s = skill["source"]
        url = f"https://raw.githubusercontent.com/{s['owner']}/{s['repo']}/{s['ref']}/{s['path']}/SKILL.md"
        try:
            fm = frontmatter(fetch(url))
        except Exception as e:
            print(f"FAIL {skill['id']}: {e}", file=sys.stderr)
            failures += 1
            continue
        if not fm.get("name"):
            print(f"FAIL {skill['id']}: no frontmatter name at {url}", file=sys.stderr)
            failures += 1
            continue
        skill["name"] = fm["name"]
        skill["description"] = re.sub(r"\s+", " ", fm.get("description", "")).strip()
        print(f"ok   {skill['id']}")
    ids = {s["id"] for s in data["skills"]}
    for b in data["bundles"]:
        missing = [i for i in b["skills"] if i not in ids]
        if missing:
            print(f"FAIL bundle {b['id']} references unknown skills {missing}", file=sys.stderr)
            failures += 1
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
