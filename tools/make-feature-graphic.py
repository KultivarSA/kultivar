"""Generate the Google Play Store feature graphic (1024 × 500 PNG).

Play requires a 1024×500 PNG as the hero image at the top of the
listing.  This script produces it directly via PIL so we don't depend
on Inkscape / ImageMagick / Chrome being on PATH.

Design mirrors the brand bar in `assets/branding/social/twitter_header_1500x500.svg`
but reformatted for the Play feature graphic aspect ratio:

  - Dark background (#0A0A0F)
  - Soft green radial glow at the top edge
  - Subtle horizontal grid lines
  - Brand K icon (rounded green square + K monogram) on the left
  - "Kultivar" wordmark
  - Tagline:  "Your grow journal." ("Not theirs." in accent green)

Run:
    python tools/make-feature-graphic.py

Output:
    store_metadata/android/en-US/images/featureGraphic.png
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from pathlib import Path

import numpy as np

# ── Constants ─────────────────────────────────────────────────────────
WIDTH = 1024
HEIGHT = 500

BG = (10, 10, 15)            # #0A0A0F
PRIMARY = (0, 200, 150)      # #00C896 brand green
TEXT_LIGHT = (240, 240, 255) # #F0F0FF
TEXT_MUTED = (144, 144, 170) # #9090AA
DARK = (10, 10, 15)          # K stroke colour (matches bg for contrast on green)

# Fonts — Segoe UI is bundled with Windows.  Falls back to default
# bitmap font if missing, so the script still works on machines
# without the exact face.
def _font(name: str, size: int) -> ImageFont.FreeTypeFont:
    for candidate in (
        f"C:/Windows/Fonts/{name}.ttf",
        f"C:/Windows/Fonts/{name}.TTF",
    ):
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


FONT_TITLE = _font("segoeuib", 92)         # "Kultivar" bold
FONT_TAGLINE = _font("segoeui", 36)        # "Your grow journal."
FONT_TAGLINE_BOLD = _font("segoeuib", 36)  # "Not theirs."

# ── Canvas ────────────────────────────────────────────────────────────
img = Image.new("RGB", (WIDTH, HEIGHT), BG)
draw = ImageDraw.Draw(img, "RGBA")

# Top radial glow — approximate the SVG radialGradient cx=50% cy=0%
# by drawing a soft circle off the top edge with a Gaussian blur.
glow_layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow_layer)
glow_radius = 520
glow_centre = (WIDTH // 2, -120)
glow_draw.ellipse(
    [
        glow_centre[0] - glow_radius,
        glow_centre[1] - glow_radius,
        glow_centre[0] + glow_radius,
        glow_centre[1] + glow_radius,
    ],
    fill=(*PRIMARY, 60),
)
glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=80))
img = Image.alpha_composite(img.convert("RGBA"), glow_layer).convert("RGB")
draw = ImageDraw.Draw(img, "RGBA")

# (Earlier revision had four faint horizontal grid lines for texture.
# Marco flagged them as visually distracting in the rendered feature
# graphic -- dropped.  The radial glow alone provides enough subtle
# atmosphere without competing with the brand mark.)

# ── Brand icon (rounded square + K monogram) ──────────────────────────
ICON_SIZE = 140
ICON_X = 230
ICON_Y = (HEIGHT - ICON_SIZE) // 2   # vertically centred

# Drop shadow underneath the icon — soft green glow that matches the
# brand colour, mimics the SVG `filter: drop-shadow(0 0 24px rgba(0,200,150,.55))`.
shadow_layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
shadow_draw = ImageDraw.Draw(shadow_layer)
shadow_draw.rounded_rectangle(
    [ICON_X - 14, ICON_Y - 14, ICON_X + ICON_SIZE + 14, ICON_Y + ICON_SIZE + 14],
    radius=32,
    fill=(*PRIMARY, 140),
)
shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=22))
img = Image.alpha_composite(img.convert("RGBA"), shadow_layer).convert("RGB")
draw = ImageDraw.Draw(img, "RGBA")

# The rounded square itself
draw.rounded_rectangle(
    [ICON_X, ICON_Y, ICON_X + ICON_SIZE, ICON_Y + ICON_SIZE],
    radius=30,
    fill=PRIMARY,
)

# Composite the *real* Kultivar K from icon_foreground.png on top.
# Earlier revision drew three geometric strokes that approximated the
# letter but lost the leaf-curl character of the actual mark.  Load
# the brand asset, resize it to fit inside the icon tile with a
# ~12 % inset, and paste using its own alpha channel.  The asset is
# a white K on a transparent canvas, which reads cleanly on the
# brand-green tile.
K_INSET = int(ICON_SIZE * 0.12)
k_target_size = ICON_SIZE - 2 * K_INSET

k_logo_path = Path("assets/branding/icon_foreground.png")
if not k_logo_path.exists():
    raise FileNotFoundError(
        f"Brand K asset missing: {k_logo_path}.  Run "
        "`dart run flutter_launcher_icons` or restore the file."
    )

k_logo = Image.open(k_logo_path).convert("RGBA")

# The brand asset is designed for Android's adaptive icon foreground
# layer -- 1024 sq with the K occupying only the centre ~55 % so the
# launcher has safe-zone room to crop.  For the Play feature graphic
# we want the K filling the green tile.
#
# Centring an asymmetric letter like K is harder than it looks.
# Two compounding issues with a naive bbox crop + square resize:
#
#   1. **Bbox centre != visual centre.**  The K's vertical bar is a
#      dense column on the left; the angled arms stretch the bbox
#      right by maybe 40 % of the letter's width but contribute much
#      less ink mass than the bar.  Cropping to bbox then centring
#      shifts the optical centre rightward of the tile centre.
#
#   2. **Aspect ratio distortion.**  The K's bbox is roughly square
#      but not exactly -- resizing a 600x520 ink box to 110x110
#      stretches the K horizontally.
#
# Fix: crop to bbox, then pad asymmetrically with transparent space
# so the *alpha centroid* lands at the geometric centre of a square
# canvas.  Square-to-square resize preserves aspect ratio and the
# centroid stays put.
ink_box = k_logo.getbbox()
if ink_box is not None:
    k_logo = k_logo.crop(ink_box)

# Compute the alpha-weighted centroid (centre of "ink mass") in
# numpy -- two reductions over a ~600 sq array, takes < 5 ms.
k_array = np.asarray(k_logo)
alpha = k_array[..., 3].astype(np.float32)
total = alpha.sum()
if total > 0:
    ys, xs = np.indices(alpha.shape)
    centroid_x = float((xs * alpha).sum() / total)
    centroid_y = float((ys * alpha).sum() / total)
else:
    centroid_x, centroid_y = k_logo.width / 2, k_logo.height / 2

# Pad asymmetrically so the centroid ends up at the centre of the
# padded canvas.  Whichever side has more ink past the centroid
# defines the half-extent; the other side gets transparent padding
# to match.  Result: visual centre == geometric centre.
half_w = max(centroid_x, k_logo.width - centroid_x)
half_h = max(centroid_y, k_logo.height - centroid_y)
canvas_side = int(round(2 * max(half_w, half_h)))

centred = Image.new("RGBA", (canvas_side, canvas_side), (0, 0, 0, 0))
paste_x = int(round(canvas_side / 2 - centroid_x))
paste_y = int(round(canvas_side / 2 - centroid_y))
centred.paste(k_logo, (paste_x, paste_y), k_logo)

# Now we can safely resize square-to-square without distorting the
# letter's proportions.  `Resampling.LANCZOS` keeps the curved K
# edges crisp at the smaller target size.
k_logo = centred.resize(
    (k_target_size, k_target_size), Image.Resampling.LANCZOS
)

img.paste(
    k_logo,
    (ICON_X + K_INSET, ICON_Y + K_INSET),
    k_logo,  # use the PNG's own alpha as the paste mask
)
draw = ImageDraw.Draw(img, "RGBA")

# ── Wordmark "Kultivar" ───────────────────────────────────────────────
text_x = ICON_X + ICON_SIZE + 36
# Vertically center: title + tagline as one block
title_bbox = draw.textbbox((0, 0), "Kultivar", font=FONT_TITLE)
title_h = title_bbox[3] - title_bbox[1]
# textbbox returns the ink box, not the line box, so naive
# title_h underestimates the descender depth.  At 92 px Segoe UI
# Bold the "K" descender + "Y" / "g" / "j" ascenders need ~52 px
# of clearance to look comfortably separated.  Earlier revisions
# at 18 / 36 had the tagline grazing the K's bottom edge --
# Marco's specific complaint.
tagline_y_gap = 52

# Combined block height ≈ title + gap + tagline
tagline_bbox = draw.textbbox((0, 0), "Your grow journal.", font=FONT_TAGLINE)
tagline_h = tagline_bbox[3] - tagline_bbox[1]
block_h = title_h + tagline_y_gap + tagline_h
block_top = (HEIGHT - block_h) // 2 - 20  # nudge up so it sits visually centred

draw.text((text_x, block_top), "Kultivar", font=FONT_TITLE, fill=TEXT_LIGHT)

# ── Tagline:  "Your grow journal. Not theirs." ────────────────────────
tagline_y = block_top + title_h + tagline_y_gap
first = "Your grow journal."
second = " Not theirs."

draw.text((text_x, tagline_y), first, font=FONT_TAGLINE, fill=TEXT_MUTED)
first_width = draw.textbbox((0, 0), first, font=FONT_TAGLINE)[2]
draw.text((text_x + first_width, tagline_y), second, font=FONT_TAGLINE_BOLD, fill=PRIMARY)

# ── Write the output ──────────────────────────────────────────────────
out_dir = Path("store_metadata/android/en-US/images")
out_dir.mkdir(parents=True, exist_ok=True)
out_path = out_dir / "featureGraphic.png"
img.save(out_path, "PNG", optimize=True)

print(f"Wrote {out_path} ({out_path.stat().st_size // 1024} KB, {WIDTH}x{HEIGHT})")
