#!/usr/bin/env python3
"""Fail if the palettes in NextCup/DesignSystem/Tokens.swift drift from docs/design/tokens/*.json.
steelKraft is tokens.light.json + tokens.dark.json; every other style is <style>.json.
usage: python3 design/check_tokens.py   (run from the repo root)"""
import json, re, sys
swift = open("NextCup/DesignSystem/Tokens.swift").read()
tokens = "docs/design/tokens/"
camel = lambda k: re.sub(r"-(\w)", lambda m: m.group(1).upper(), k)

def load(style):
    if style == "steelKraft":
        return json.load(open(tokens + "tokens.light.json"))["color"], json.load(open(tokens + "tokens.dark.json"))["color"]
    data = json.load(open(tokens + style + ".json"))
    return data["light"], data["dark"]

bad = 0
blocks = re.findall(r"case \.(\w+):\s*Palette\((.*?)\)\n(?=\s*(?:case|\}))", swift, re.S)
if len(blocks) != 12:
    print(f"expected 12 palettes, found {len(blocks)}"); sys.exit(1)
for style, body in blocks:
    found = {m.group(1): (m.group(2).upper(), m.group(3).upper()) for m in re.finditer(r"(\w+): P\(0x([0-9A-Fa-f]{6}), 0x([0-9A-Fa-f]{6})\)", body)}
    light, dark = load(style)
    for key in light:
        want = (light[key].lstrip("#").upper(), dark[key].lstrip("#").upper())
        if found.get(camel(key)) != want:
            print(f"DRIFT {style}.{camel(key)}: swift={found.get(camel(key))} json={want}"); bad += 1
    for e in sorted(set(found) - {camel(k) for k in light}):
        print(f"EXTRA in swift, not in json: {style}.{e}"); bad += 1
print("tokens in sync" if not bad else f"{bad} problem(s)"); sys.exit(1 if bad else 0)
