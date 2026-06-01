#!/usr/bin/env python3
"""SR3 — Generates `docs/privacy.html` + `docs/terms.html` from the
in-app legal markdown in `lib/legal/*.dart`.

Single source of truth: the markdown lives in the Dart consts so the
in-app viewer renders the same text the public URL serves.  When the
in-app policy changes, re-run:

    python tools/generate_legal_html.py

Both HTML files are checked into git; GitHub Pages serves them from
`/docs` automatically once the repo enables Pages → main → /docs.

No build dependencies — uses Python's stdlib `re` + a hand-rolled
markdown subset.  The in-app docs use a constrained subset (headings,
bold, italics, links, lists, hr) that's tiny to render correctly
without pulling in a markdown library.
"""
from __future__ import annotations

import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB_LEGAL = ROOT / "lib" / "legal"
DOCS = ROOT / "docs"


# ── Markdown extractor ───────────────────────────────────────────────────────

def extract_const(dart_file: Path, name: str) -> str:
    """Reads a raw-string Dart const named [name] and returns its body."""
    src = dart_file.read_text(encoding="utf-8")
    m = re.search(
        rf"const String {re.escape(name)} = r'''(.*?)''';",
        src,
        re.DOTALL,
    )
    if not m:
        raise SystemExit(f"Could not find const '{name}' in {dart_file}")
    return m.group(1)


def extract_version(dart_file: Path, name: str) -> str:
    src = dart_file.read_text(encoding="utf-8")
    m = re.search(rf"const String {re.escape(name)} = '([^']+)';", src)
    if not m:
        raise SystemExit(f"Could not find const '{name}' in {dart_file}")
    return m.group(1)


# ── Markdown → HTML renderer ─────────────────────────────────────────────────
#
# Hand-rolled because the in-app docs use a small, predictable subset
# and pulling `markdown` or `mistune` as a build dep would mean an extra
# `pip install` step for whoever regenerates the pages.

def render_markdown(md: str) -> str:
    lines = md.split("\n")
    out: list[str] = []
    in_list: str | None = None  # 'ul' or 'ol' when inside a list
    in_paragraph_lines: list[str] = []

    def flush_paragraph() -> None:
        nonlocal in_paragraph_lines
        if not in_paragraph_lines:
            return
        joined = " ".join(in_paragraph_lines).strip()
        if joined:
            out.append(f"<p>{render_inline(joined)}</p>")
        in_paragraph_lines = []

    def close_list() -> None:
        nonlocal in_list
        if in_list:
            out.append(f"</{in_list}>")
            in_list = None

    for line in lines:
        stripped = line.rstrip()

        # ── Headings ──
        h = re.match(r"^(#{1,6})\s+(.*)$", stripped)
        if h:
            flush_paragraph()
            close_list()
            level = len(h.group(1))
            out.append(
                f"<h{level}>{render_inline(h.group(2))}</h{level}>"
            )
            continue

        # ── Horizontal rule ──
        if re.match(r"^---+$", stripped):
            flush_paragraph()
            close_list()
            out.append("<hr>")
            continue

        # ── Unordered list ──
        ul = re.match(r"^[-*]\s+(.*)$", stripped)
        if ul:
            flush_paragraph()
            if in_list != "ul":
                close_list()
                out.append("<ul>")
                in_list = "ul"
            out.append(f"  <li>{render_inline(ul.group(1))}</li>")
            continue

        # ── Ordered list ──
        ol = re.match(r"^\d+\.\s+(.*)$", stripped)
        if ol:
            flush_paragraph()
            if in_list != "ol":
                close_list()
                out.append("<ol>")
                in_list = "ol"
            out.append(f"  <li>{render_inline(ol.group(1))}</li>")
            continue

        # ── Blank line: paragraph / list break ──
        if not stripped:
            flush_paragraph()
            close_list()
            continue

        # ── Paragraph continuation ──
        close_list()
        in_paragraph_lines.append(stripped)

    # End of input: flush any pending blocks.
    flush_paragraph()
    close_list()
    return "\n".join(out)


def render_inline(text: str) -> str:
    """Inline rules — link, **bold**, *italic*, `code`.  Escapes HTML
    first so user-supplied text can't smuggle markup."""
    out = html.escape(text, quote=False)

    # Markdown link `[label](url)` — supports https/mailto.
    out = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        lambda m: f'<a href="{html.escape(m.group(2), quote=True)}" '
        f"rel=\"noopener noreferrer\" target=\"_blank\">"
        f"{m.group(1)}</a>",
        out,
    )

    # Bold then italic then inline code (order matters — bold's `**`
    # mustn't be eaten by italic's `*`).
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"<em>\1</em>", out)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)

    return out


# ── HTML page template ──────────────────────────────────────────────────────

PAGE_CSS = """
  :root {
    --bg: #0A0A0F;
    --surface-1: #13131A;
    --surface-2: #1C1C27;
    --border: #2A2A3D;
    --border-faint: #26263B;
    --primary: #00C896;
    --text-primary: #F0F0FF;
    --text-secondary: #9090AA;
    --text-muted: #5A5A70;
    --max-width: 720px;
  }

  * { box-sizing: border-box; }

  html { -webkit-text-size-adjust: 100%; }

  body {
    margin: 0;
    padding: 0;
    background: var(--bg);
    color: var(--text-primary);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
      Oxygen-Sans, Ubuntu, Cantarell, "Helvetica Neue", sans-serif;
    font-size: 16px;
    line-height: 1.6;
    -webkit-font-smoothing: antialiased;
  }

  .container {
    max-width: var(--max-width);
    margin: 0 auto;
    padding: 32px 24px 80px;
  }

  header.site {
    border-bottom: 1px solid var(--border-faint);
    padding: 20px 24px;
    background: var(--surface-1);
  }

  header.site .brand {
    max-width: var(--max-width);
    margin: 0 auto;
    display: flex;
    align-items: center;
    gap: 10px;
  }

  header.site .wordmark {
    color: var(--primary);
    font-weight: 700;
    font-size: 18px;
    letter-spacing: -0.2px;
    text-decoration: none;
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }
  header.site .wordmark-icon {
    width: 22px;
    height: 22px;
    border-radius: 6px;
    filter: drop-shadow(0 0 10px rgba(0, 200, 150, 0.45));
    flex-shrink: 0;
  }

  .meta {
    color: var(--text-muted);
    font-size: 13px;
    margin: 0 0 32px;
  }

  h1, h2, h3, h4, h5, h6 {
    color: var(--text-primary);
    letter-spacing: -0.2px;
    line-height: 1.25;
    margin: 32px 0 12px;
  }
  h1 { font-size: 28px; margin-top: 0; }
  h2 { font-size: 22px; }
  h3 { font-size: 18px; }
  h4 { font-size: 16px; color: var(--text-secondary); }

  p, ul, ol { margin: 0 0 16px; color: var(--text-primary); }

  ul, ol { padding-left: 24px; }
  li { margin-bottom: 6px; }

  a {
    color: var(--primary);
    text-decoration: none;
    border-bottom: 1px solid rgba(0, 200, 150, 0.35);
    transition: border-color 0.15s ease;
  }
  a:hover { border-bottom-color: var(--primary); }

  hr {
    border: none;
    border-top: 1px solid var(--border-faint);
    margin: 32px 0;
  }

  code {
    background: var(--surface-2);
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 14px;
    font-family: "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
    color: var(--primary);
  }

  strong { color: var(--text-primary); }

  footer.site {
    border-top: 1px solid var(--border-faint);
    padding: 24px;
    color: var(--text-muted);
    font-size: 13px;
    text-align: center;
  }

  footer.site a { color: var(--text-secondary); border-bottom-color: transparent; }
  footer.site a:hover { color: var(--primary); }

  @media (max-width: 480px) {
    .container { padding: 24px 16px 64px; }
    h1 { font-size: 24px; }
    h2 { font-size: 20px; }
  }
"""

PAGE_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#0A0A0F">
  <meta name="color-scheme" content="dark">
  <meta name="robots" content="index,follow">
  <meta name="description" content="{description}">
  <title>{title} — Kultivar</title>
  <link rel="icon" type="image/png" href="favicon.png">
  <link rel="apple-touch-icon" href="apple-touch-icon.png">
  <style>{css}</style>
</head>
<body>
  <header class="site">
    <div class="brand">
      <a class="wordmark" href="./"><img class="wordmark-icon" src="favicon.png" alt="" width="22" height="22"><span>Kultivar</span></a>
    </div>
  </header>
  <main class="container">
    <p class="meta">Version {version} · <a href="./">Back to index</a></p>
{body}
  </main>
  <footer class="site">
    <p>
      © Kultivar.
      The in-app version of this document is identical and lives under
      <strong>Settings → Legal</strong>.
    </p>
  </footer>
</body>
</html>
"""

INDEX_HTML = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#0A0A0F">
  <meta name="color-scheme" content="dark">
  <meta name="description" content="Kultivar — privacy policy and terms of service.">
  <title>Kultivar — Legal</title>
  <link rel="icon" type="image/png" href="favicon.png">
  <link rel="apple-touch-icon" href="apple-touch-icon.png">
  <style>{css}</style>
  <style>
    .doc-grid {{
      display: grid;
      gap: 16px;
      margin-top: 24px;
    }}
    @media (min-width: 600px) {{ .doc-grid {{ grid-template-columns: 1fr 1fr; }} }}
    .doc-card {{
      background: var(--surface-1);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 20px;
      transition: border-color 0.15s ease, transform 0.15s ease;
    }}
    .doc-card:hover {{ border-color: var(--primary); transform: translateY(-1px); }}
    .doc-card h2 {{ margin-top: 0; font-size: 18px; }}
    .doc-card p {{ color: var(--text-secondary); font-size: 14px; margin-bottom: 12px; }}
    .doc-card a.cta {{
      display: inline-block;
      color: var(--primary);
      font-weight: 600;
      border-bottom: none;
    }}
  </style>
</head>
<body>
  <header class="site">
    <div class="brand">
      <a class="wordmark" href="./"><img class="wordmark-icon" src="favicon.png" alt="" width="22" height="22"><span>Kultivar</span></a>
    </div>
  </header>
  <main class="container">
    <h1>Legal</h1>
    <p style="color: var(--text-secondary)">
      These documents mirror the versions shown inside the app under
      <strong>Settings → Legal</strong>.  The hosted copy is the URL we
      give the App Store and Google Play; updates land in both surfaces
      together.
    </p>

    <div class="doc-grid">
      <div class="doc-card">
        <h2>Privacy Policy</h2>
        <p>What we store, what we send, and what stays on your device.</p>
        <a class="cta" href="privacy.html">Read →</a>
      </div>
      <div class="doc-card">
        <h2>Terms of Service</h2>
        <p>The deal between you and Kultivar, in plain English.</p>
        <a class="cta" href="terms.html">Read →</a>
      </div>
    </div>
  </main>
  <footer class="site">
    <p>
      © Kultivar.  Built for serious growers.
      The <a href="https://github.com/">app source</a> is available
      separately; this page only carries the legal text.
    </p>
  </footer>
</body>
</html>
"""


# ── Driver ───────────────────────────────────────────────────────────────────

def main() -> None:
    DOCS.mkdir(exist_ok=True)

    # ── Privacy Policy ──
    privacy_md = extract_const(
        LIB_LEGAL / "privacy_policy.dart", "kPrivacyPolicyMarkdown"
    )
    privacy_version = extract_version(
        LIB_LEGAL / "privacy_policy.dart", "kPrivacyPolicyVersion"
    )
    privacy_html = render_markdown(privacy_md)
    (DOCS / "privacy.html").write_text(
        PAGE_TEMPLATE.format(
            css=PAGE_CSS,
            title="Privacy Policy",
            description="How Kultivar stores your grow data and what we never share.",
            version=privacy_version,
            body=privacy_html,
        ),
        encoding="utf-8",
        newline="\n",
    )

    # ── Terms of Service ──
    terms_md = extract_const(
        LIB_LEGAL / "terms_of_service.dart", "kTermsOfServiceMarkdown"
    )
    terms_version = extract_version(
        LIB_LEGAL / "terms_of_service.dart", "kTermsOfServiceVersion"
    )
    terms_html = render_markdown(terms_md)
    (DOCS / "terms.html").write_text(
        PAGE_TEMPLATE.format(
            css=PAGE_CSS,
            title="Terms of Service",
            description="The agreement between you and Kultivar — plain-English version.",
            version=terms_version,
            body=terms_html,
        ),
        encoding="utf-8",
        newline="\n",
    )

    # ── Legal index (separate page; the marketing landing now owns
    # docs/index.html so we publish the legal index at /legal.html). ──
    #
    # Why we don't write docs/index.html here anymore: that path now
    # serves the marketing landing page hand-authored at
    # docs/index.html.  The legal index (which routes between Privacy
    # and Terms) lives at /legal.html so it survives regenerations.
    # In-app links in lib/legal/ and Play Store URLs point directly
    # at /privacy.html and /terms.html, so this rename is invisible
    # to users.
    (DOCS / "legal.html").write_text(
        INDEX_HTML.format(css=PAGE_CSS),
        encoding="utf-8",
        newline="\n",
    )

    print("Generated docs/legal.html, docs/privacy.html, docs/terms.html")
    print(f"  privacy version: {privacy_version}")
    print(f"  terms version:   {terms_version}")
    print("  (docs/index.html is the marketing landing — not regenerated)")


if __name__ == "__main__":
    sys.exit(main() or 0)
