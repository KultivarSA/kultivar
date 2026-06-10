"""Sweep helper — verify every locale ARB carries the same key set as
app_en.arb.  Missing keys silently fall back to English at runtime, so a
drifted locale ships half-translated with no build error.
Run from repo root:  python tools/check_arb_consistency.py
Exit 1 when any locale is missing keys.
"""
import glob
import io
import json
import os
import sys

files = sorted(glob.glob(os.path.join("lib", "l10n", "app_*.arb")))
keysets = {}
for f in files:
    with io.open(f, encoding="utf-8") as fh:
        d = json.load(fh)
    keysets[f] = {k for k in d if not k.startswith("@")}

en_file = next(f for f in files if f.endswith("app_en.arb"))
en = keysets[en_file]
bad = False
for f, ks in sorted(keysets.items()):
    missing = en - ks
    extra = ks - en
    status = "OK " if not missing and not extra else "DRIFT"
    print(f"{status} {os.path.basename(f)}  keys={len(ks)}  missing={len(missing)}  extra={len(extra)}")
    for m in sorted(missing)[:15]:
        print(f"      MISSING: {m}")
        bad = True
    for e in sorted(extra)[:15]:
        print(f"      EXTRA:   {e}")

sys.exit(1 if bad else 0)
