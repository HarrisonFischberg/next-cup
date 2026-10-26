"""Join each look's six raw shots (journal, timer, log x light, dark) into one labelled strip.
usage: python3 design/compose-looks.py <out-dir> <n:Title>..."""
import sys
from PIL import Image, ImageDraw, ImageFont

out, items = sys.argv[1], sys.argv[2:]
font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 44)
for item in items:
    n, title = item.split(":", 1)
    shots = [Image.open(f"{out}/raw/{n}-{s}-{m}.png") for m in ("light", "dark") for s in ("journal", "timer", "log")]
    w, h = shots[0].width // 3, shots[0].height // 3
    gap, top = 16, 90
    sheet = Image.new("RGB", (gap + 6 * (w + gap), top + h + gap), (242, 239, 234))
    ImageDraw.Draw(sheet).text((gap, 22), f"{n}. {title}", fill=(20, 20, 20), font=font)
    for i, s in enumerate(shots):
        sheet.paste(s.convert("RGB").resize((w, h), Image.LANCZOS), (gap + i * (w + gap), top))
    slug = title.lower().replace(" ", "-")
    sheet.save(f"{out}/look-{n}-{slug}.png", optimize=True)
    print(f"{out}/look-{n}-{slug}.png")
