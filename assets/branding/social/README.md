# Social media banner kit

Branded cover banners for Kultivar's social presence.  All files are
hand-authored SVG — vector source, zero external dependencies, edit
freely in any text editor or SVG tool (Inkscape, Figma, Illustrator).

## What's in here

| File | Platform | Pixel size | Use |
|---|---|---|---|
| `twitter_header_1500x500.svg` | X (Twitter) | 1500 × 500 | Profile header banner |
| `linkedin_personal_1584x396.svg` | LinkedIn | 1584 × 396 | Personal profile cover |
| `youtube_channel_art_2560x1440.svg` | YouTube | 2560 × 1440 | Channel art (with mobile/desktop/TV safe areas) |
| `facebook_cover_851x315.svg` | Facebook | 851 × 315 | Page cover |
| `discord_banner_960x540.svg` | Discord | 960 × 540 | Server invite splash background |

## Design language

Every banner uses the same brand grammar so the social presence reads
coherently:

- **Background:** `#0A0A0F` (Kultivar's surface-0 / deepest dark) with
  subtle radial gradients in primary teal (`#00C896`), occasional
  secondary purple (`#7B61FF`), and accent amber (`#FFB547`).
- **Icon:** A rounded-square in primary teal with a stylised "K"
  letterform.  Drop-shadow glow halo in matching colour.
- **Wordmark:** "Kultivar" in the system font stack (SF Pro on Apple
  surfaces, Segoe UI on Windows, Roboto on Linux/Android).
- **Tagline:** "Your grow journal. **Not theirs.**" — the canonical
  product positioning from the landing page.
- **URL chip:** `KULTIVAR.IO` at the bottom right or center, faint and
  understated so it doesn't compete with the wordmark.

## Most social platforms need PNG/JPG, not SVG

LinkedIn, Facebook, YouTube, Discord, and X all accept PNG or JPG
uploads for cover images.  None accept raw SVG.  Convert each SVG to
PNG before uploading.

### Conversion options — pick one

#### 1. Browser screenshot (zero install, 30 seconds)

Best for one-off conversion when you don't already have image tools
installed.

1. Open the SVG file in Chrome / Edge / Firefox by double-clicking it
2. Press **F12** to open DevTools → Device Toolbar (Ctrl+Shift+M)
3. Set the device dimensions to the exact pixel size from the table
   above (e.g. 1500 × 500 for Twitter)
4. Right-click the page → **Capture screenshot**
5. PNG lands in your Downloads folder

#### 2. Inkscape command line (best quality)

If you'll be regenerating these often:

```powershell
winget install Inkscape.Inkscape

# Convert one banner
inkscape twitter_header_1500x500.svg --export-type=png --export-filename=twitter_header_1500x500.png

# Convert all five in one go
foreach ($svg in Get-ChildItem *.svg) {
    inkscape $svg --export-type=png --export-filename="$($svg.BaseName).png"
}
```

Inkscape preserves text rendering exactly (no font fallback surprises)
and produces pixel-perfect output at any resolution.

#### 3. ImageMagick (cross-platform, scriptable)

```powershell
winget install ImageMagick.ImageMagick

# Convert one
magick -background none -density 300 twitter_header_1500x500.svg twitter_header_1500x500.png

# Batch convert all
foreach ($svg in Get-ChildItem *.svg) {
    magick -background none -density 300 $svg "$($svg.BaseName).png"
}
```

#### 4. Online (cloudconvert.com, svg2png.com)

Upload SVG → download PNG.  Fine for one-offs.  Don't paste anything
sensitive though — public converters can log uploads.

## Customising the banners

The SVGs are hand-authored XML.  Common edits you might want:

### Change the tagline

Search each file for `Your grow journal. <tspan` and replace the text.

### Add a specific marketing message

Add a new `<text>` block.  The SVG coordinate system runs top-left
to bottom-right; `viewBox` gives you the canvas dimensions.

### Add the Play Store badge

Once your Play Store listing is live, swap the "COMING SOON" text
for a "GET IT ON GOOGLE PLAY" badge.  Google's official badge assets:
[https://play.google.com/intl/en_us/badges/](https://play.google.com/intl/en_us/badges/)

Embed the official PNG as a `<image>` element in the SVG, or convert
the whole banner to a PSD/Figma file once you start iterating heavily.

## Profile pictures (separate from banners)

For your profile / avatar picture on each platform, use the existing
`assets/branding/icon_source.png` directly.  Most platforms accept
1024×1024 and downscale cleanly.  No conversion needed.

## Future banners

When you need additional sizes that aren't in this kit, the canonical
list to update:

- **Instagram profile** — uses square avatars; the icon_source.png is fine
- **Threads profile** — same as Instagram
- **TikTok profile** — same as Instagram
- **GitHub org banner** — 1280 × 640
- **GitHub social preview** (per-repo) — 1280 × 640
- **Reddit subreddit banner** — 1920 × 384
- **Mastodon profile header** — 1500 × 500 (same as Twitter)
- **WhatsApp Business profile** — uses square avatars

Copy one of the existing SVG files as a starting point, adjust the
`viewBox` to the target dimensions, and reposition the wordmark/icon
to suit the new aspect ratio.
