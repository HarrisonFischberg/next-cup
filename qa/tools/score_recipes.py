#!/usr/bin/env python3
"""Summarises qa/results/recipes-*.jsonl: per provider, how many requests got a recipe,
how many first answers already passed the app's own number and capacity rules, and how
many needed the retry or were thrown away. The rules ran in the app; this only counts."""
import collections
import glob
import json
import os
import sys

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "results")
files = sorted(glob.glob(os.path.join(root, "recipes-*.jsonl")))
if not files:
    sys.exit("no qa/results/recipes-*.jsonl; run qa/run-eval.sh <providers> recipes")
rows = [json.loads(line) for f in files for line in open(f) if line.strip()]
by = collections.defaultdict(list)
for row in rows:
    by[row["provider"]].append(row)
for provider, lines in sorted(by.items()):
    ran = [r for r in lines if r["status"] != "skipped-budget"]
    ok = [r for r in ran if r["status"] == "ok"]
    clean = [r for r in ok if r.get("firstNumbers") == "ok" and r.get("firstFits") == "ok"]
    print(f"{provider}: {len(ok)}/{len(ran)} got a recipe; {len(clean)} passed first time, "
          f"{len(ok) - len(clean)} after a retry or a fit, {len(ran) - len(ok)} failed; "
          f"est ${sum(r.get('estUSD', 0) for r in ran):.2f}")
    for r in ran:
        if r["status"] != "ok" or r not in clean:
            why = r.get("error") or "; ".join(
                x for x in (r.get("firstNumbers"), r.get("firstFits")) if x and x != "ok")
            print(f"  {r['fixture']} {r['method']} [{r['status']}] {why[:160]}")
