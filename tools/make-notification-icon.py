"""Task #179 — generate the monochrome Android status-bar notification icon.

Android requires small notification icons to be pure-white silhouettes on a
transparent background (the OS tints them); passing the full-colour launcher
icon renders as a flat white square.  This script converts the brand K
foreground into that alpha-mask format at every density bucket.

Input : assets/branding/icon_foreground.png  (full-colour K on transparency)
Output: android/app/src/main/res/drawable-{m,h,xh,xxh,xxxh}dpi/ic_stat_kultivar.png

Method: tight-crop to the alpha bounding box, scale to ~80%% of the canvas
(centres on the 24 dp grid with standard padding), then emit WHITE pixels
carrying the source alpha so anti-aliased edges stay smooth.

Run from repo root:  python tools/make-notification-icon.py
"""
import os

from PIL import Image

SRC = os.path.join("assets", "branding", "icon_foreground.png")
RES = os.path.join("android", "app", "src", "main", "res")

# Density bucket -> canvas px for a 24 dp status-bar icon.
SIZES = {
    "drawable-mdpi": 24,
    "drawable-hdpi": 36,
    "drawable-xhdpi": 48,
    "drawable-xxhdpi": 72,
    "drawable-xxxhdpi": 96,
}
INK_FRACTION = 0.80  # glyph occupies 80% of the canvas, 10% padding each side
ALPHA_CROP_THRESHOLD = 20


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    alpha = src.getchannel("A")

    # Tight-crop to the visible ink so padding is consistent regardless of
    # how much safe-zone margin the adaptive-icon source carries.
    bbox = alpha.point(lambda a: 255 if a > ALPHA_CROP_THRESHOLD else 0).getbbox()
    if bbox is None:
        raise SystemExit("source image is fully transparent")
    glyph_alpha = alpha.crop(bbox)

    for folder, canvas_px in SIZES.items():
        target = int(canvas_px * INK_FRACTION)
        w, h = glyph_alpha.size
        scale = min(target / w, target / h)
        scaled = glyph_alpha.resize(
            (max(1, round(w * scale)), max(1, round(h * scale))),
            Image.LANCZOS,
        )

        out = Image.new("RGBA", (canvas_px, canvas_px), (255, 255, 255, 0))
        white = Image.new("RGBA", scaled.size, (255, 255, 255, 255))
        white.putalpha(scaled)
        pos = ((canvas_px - scaled.width) // 2, (canvas_px - scaled.height) // 2)
        out.paste(white, pos, white)

        out_dir = os.path.join(RES, folder)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "ic_stat_kultivar.png")
        out.save(out_path)
        print(f"{out_path}  {canvas_px}x{canvas_px}")


if __name__ == "__main__":
    main()
