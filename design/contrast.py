#!/usr/bin/env python3
"""WCAG AA check of every style's text pairs (4.5:1) and UI pairs (3:1), light and dark.
Pairs come from docs/design/tokens/tokens.light.json and apply to every style.
usage: python3 design/contrast.py   (run from the repo root; exit 1 on any failure)"""
import json, sys
tokens = "docs/design/tokens/"
pairs = json.load(open(tokens + "tokens.light.json"))["pairs"]

def lum(hex_):
    c = [int(hex_.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]

def ratio(a, b):
    hi, lo = sorted((lum(a), lum(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)

styles = {"steelKraft": (json.load(open(tokens + "tokens.light.json"))["color"], json.load(open(tokens + "tokens.dark.json"))["color"])}
for s in ("bloom", "charcoalCrema", "quietCeramic", "terracotta", "lateNightCafe", "nightMint",
          "espressoBlack", "cafePage", "roasterPoster", "makeItYours"):
    d = json.load(open(tokens + s + ".json")); styles[s] = (d["light"], d["dark"])
# Every Make It Yours accent replaces signal and signal-on-steel, then runs the same pairs.
for sw in json.load(open(tokens + "makeItYours.json"))["swatches"]:
    light, dark = (dict(c) for c in styles["makeItYours"])
    light["signal"], dark["signal"] = sw["light"], sw["dark"]
    light["signal-on-steel"] = dark["signal-on-steel"] = sw["dark"]
    styles["makeItYours/" + sw["name"]] = (light, dark)

bad = 0
for style, modes in styles.items():
    for mode, colors in zip(("light", "dark"), modes):
        for fg, bg, *kind in pairs:
            need = 3.0 if kind else 4.5
            r = ratio(colors[fg], colors[bg])
            if r < need:
                print(f"FAIL {style} {mode} {fg} on {bg}: {r:.2f} < {need}"); bad += 1
print("all pairs pass WCAG AA" if not bad else f"{bad} failing pair(s)"); sys.exit(1 if bad else 0)
