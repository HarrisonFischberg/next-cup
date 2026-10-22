#!/usr/bin/env python3
"""Fail if NextCup/DesignSystem/Tokens.swift colors drift from docs/design/tokens/*.json.
usage: python3 design/check_tokens.py   (run from the repo root)"""
import json, re, sys
swift = open("NextCup/DesignSystem/Tokens.swift").read()
light = json.load(open("docs/design/tokens/tokens.light.json"))["color"]
dark = json.load(open("docs/design/tokens/tokens.dark.json"))["color"]
camel = lambda k: re.sub(r"-(\w)", lambda m: m.group(1).upper(), k)
found = {m.group(1): (m.group(2).upper(), m.group(3).upper()) for m in re.finditer(r"static let (\w+) = Color\(light: 0x([0-9A-Fa-f]{6}), dark: 0x([0-9A-Fa-f]{6})\)", swift)}
bad = 0
for key in light:
    name = camel(key)
    want = (light[key].lstrip("#").upper(), dark[key].lstrip("#").upper())
    if found.get(name) != want:
        print(f"DRIFT {name}: swift={found.get(name)} json={want}"); bad += 1
extra = set(found) - {camel(k) for k in light}
for e in sorted(extra): print(f"EXTRA in swift, not in json: {e}"); bad += 1
print("tokens in sync" if not bad else f"{bad} problem(s)"); sys.exit(1 if bad else 0)
