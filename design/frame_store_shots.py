"""Frames the raw App Store shots (docs/app-store/raw, from AppStoreCaptureUITests) into
captioned 6.9-inch (1320 x 2868) and 6.5-inch (1284 x 2778, 1242 x 2688) PNGs, in the
navy style of the 1.0 marketing set.

Usage: python3 design/frame_store_shots.py [out_dir]
Writes store/ios/screenshots/en-US (6.9 + 6.5) and, when out_dir is given, every size there.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "docs/app-store/raw"
STORE = ROOT / "store/ios/screenshots/en-US"
SF = "/System/Library/Fonts/SFNS.ttf"
W, H = 1320, 2868

# (raw name, headline, subtitle), in store order.
SHOTS = [
    ("01-next-cup", "Your next cup is\nalready planned",
     "Ask AI for Next Cup looks at your brews, writes a better recipe and pins it to the Brew tab."),
    ("02-ask-ai", "Try a finer grind\nand hotter water",
     "It compares this cup with your similar brews and tells you why each change should help."),
    ("03-start-brew", "Say how much\ncoffee you want",
     "The dose and water scale to fit. Tap − or + to adjust, or hold one for a dial."),
    ("04-timer", "The timer tells\nyou when to pour",
     "You'll see the current step on screen, on your Lock Screen and in the Dynamic Island."),
    ("06-taste", "How did this\ncup taste?",
     "Tick what you noticed, like sour or watery, and Next Cup works out what to change."),
    ("05-journal", "Look back at\nevery brew",
     "Each one keeps its dose, water, grind, time, taste and rating."),
    ("07-beans", "Scan the bag to\nadd your beans",
     "A barcode or QR code fills in the details, and you can see how much is left."),
    ("08-privacy", "Your journal stays\non your iPhone",
     "There's no account to make, and no ads or analytics."),
]
SIZES = {"6.9": (1320, 2868), "6.9-alt": (1290, 2796), "6.5": (1284, 2778), "6.5-small": (1242, 2688)}
IN_STORE = {"6.9", "6.5"}


def font(size, weight):
    # SFNS axes: Width, Optical Size, GRAD, Weight.
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_axes([100, min(size, 96), 400, weight])
    return f


def background():
    # Navy with a lighter glow at the top centre, as in the 1.0 set.
    bg = Image.new("RGB", (W, H), (11, 15, 38))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((-200, -900, W + 200, 1500), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(260))
    return Image.composite(Image.new("RGB", (W, H), (36, 48, 108)), bg, glow)


def wrap(text, f, width, draw):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=f) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def frame(raw, headline, subtitle):
    im = background()
    d = ImageDraw.Draw(im)
    x = 110
    kicker = font(40, 700)
    cx = x
    for ch in "NEXT CUP":  # tracked caps
        d.text((cx, 190), ch, font=kicker, fill=(240, 138, 60))
        cx += d.textlength(ch, font=kicker) + 7
    head = font(116, 800)
    y = 262
    for line in headline.split("\n"):
        d.text((x - 4, y), line, font=head, fill="white")
        y += 124
    sub = font(46, 400)
    y += 44
    for line in wrap(subtitle, sub, W - 2 * x, d):
        d.text((x, y), line, font=sub, fill=(196, 202, 238))
        y += 64

    # Phone: dark bezel, rounded screen, running off the bottom edge.
    top, left, bezel, radius = max(y + 90, 800), 170, 20, 120
    sw = W - 2 * left - 2 * bezel
    shot = raw.convert("RGB").resize((sw, round(raw.height * sw / raw.width)), Image.LANCZOS)
    pw, ph = sw + 2 * bezel, shot.height + 2 * bezel
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left, top + 30, left + pw, top + ph + 30), radius + bezel, fill=150)
    im.paste((5, 7, 20), mask=shadow.filter(ImageFilter.GaussianBlur(50)))
    d.rounded_rectangle((left, top, left + pw, top + ph), radius + bezel, fill=(8, 10, 24),
                        outline=(52, 60, 110), width=3)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *shot.size), radius, fill=255)
    im.paste(shot, (left + bezel, top + bezel), mask)
    return im


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    for old in STORE.glob("*.png"):
        old.unlink()
    for i, (name, headline, subtitle) in enumerate(SHOTS, 1):
        full = frame(Image.open(RAW / f"{name}.png"), headline, subtitle)
        slug = name.split("-", 1)[1]
        for size, (w, h) in SIZES.items():
            scaled = full.resize((w, round(H * w / W)), Image.LANCZOS).crop((0, 0, w, h))
            assert scaled.size == (w, h)
            if size in IN_STORE:
                scaled.save(STORE / f"{i}-{slug}-{size}.png")
            if out:
                (out / size).mkdir(parents=True, exist_ok=True)
                scaled.save(out / size / f"{i:02d}-{slug}.png")


if __name__ == "__main__":
    main()
