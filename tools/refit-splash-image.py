"""Refit the splash branding wordmark to a tight crop.

`assets/branding/splash_image.png` was authored as a 1536x1024 canvas
with the K + "Kultivar" wordmark sitting in the upper-left ~49 x 22 %
of the area.  That's fine for iOS / legacy Android where the image is
centred at full size, but Android 12+'s splash API scales this asset
into a small 200 x 80 dp branding slot at the bottom of the screen --
and most of that slot ends up empty padding around a tiny rendered
wordmark.  Marco's splash screenshot showed the wordmark squashed
into a corner of an otherwise empty bottom strip.

Fix:  crop the canvas to the actual ink (alpha > 20 to ignore
anti-aliased near-transparent edge pixels), then add a uniform 8 %
breathing-room margin so the asset still looks balanced when used
full-size on legacy splashes.  Save back to the same path; rerun
`dart run flutter_native_splash:create` afterward to push the
regenerated assets into android/ and ios/.

Run:
    python tools/refit-splash-image.py
"""
from PIL import Image
from pathlib import Path

import numpy as np

SRC = Path("assets/branding/splash_image.png")
# Pixels with alpha below this are treated as "background" for the
# purpose of the crop.  20 is permissive enough to keep the curl of
# the K's anti-aliased edges intact while ignoring the faint sub-1 %
# fringe that PIL.getbbox() picks up.
ALPHA_THRESHOLD = 20
# Breathing room added uniformly on all four sides after the tight
# crop, expressed as a fraction of the longer cropped dimension.
PADDING_FRACTION = 0.08

img = Image.open(SRC).convert("RGBA")
arr = np.asarray(img)
alpha = arr[..., 3]
visible = alpha > ALPHA_THRESHOLD

if not visible.any():
    raise SystemExit(f"No visible ink found in {SRC} -- aborting.")

ys, xs = np.where(visible)
x0, y0 = int(xs.min()), int(ys.min())
x1, y1 = int(xs.max() + 1), int(ys.max() + 1)

ink = img.crop((x0, y0, x1, y1))
ink_w, ink_h = ink.size

pad = int(round(max(ink_w, ink_h) * PADDING_FRACTION))
out_w = ink_w + 2 * pad
out_h = ink_h + 2 * pad

canvas = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
canvas.paste(ink, (pad, pad))
canvas.save(SRC, "PNG", optimize=True)

print(
    f"Refit complete.\n"
    f"  Before: {img.size[0]} x {img.size[1]}  "
    f"(ink occupied {ink_w}x{ink_h} = "
    f"{(ink_w*ink_h)/(img.size[0]*img.size[1])*100:.1f}% of canvas)\n"
    f"  After:  {out_w} x {out_h}  "
    f"(ink occupies {ink_w}x{ink_h} = "
    f"{(ink_w*ink_h)/(out_w*out_h)*100:.1f}% of canvas)\n"
    f"\n"
    f"Next:  dart run flutter_native_splash:create\n"
    f"to regenerate the platform splash assets in android/ and ios/."
)
