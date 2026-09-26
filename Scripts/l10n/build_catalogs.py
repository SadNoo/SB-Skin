#!/usr/bin/env python3
"""Regenerates the Localizable.xcstrings catalogs of SBSkin, SBSkinShared and SBSkinWidgets.

Keys are the English source strings passed to SkinL / Text(skin:) / SharedL / WidgetL.
Translations live in Scripts/l10n/<locale>.json (one flat table shared by all modules).
Run from the repository root:  python3 Scripts/l10n/build_catalogs.py
Missing translations are listed and exit status is 1.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOCALES = ["zh-Hans", "zh-Hant"]
MODULES = ["SBSkin", "SBSkinShared", "SBSkinWidgets"]
PATTERN = re.compile(
    r'\b(?:SkinL|SharedL|WidgetL)\(\s*"((?:[^"\\]|\\.)*)"|Text\(skin:\s*"((?:[^"\\]|\\.)*)"'
)


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in s else s


def main():
    tables = {loc: json.load(open(os.path.join(ROOT, "Scripts/l10n", f"{loc}.json"), encoding="utf-8")) for loc in LOCALES}
    missing = set()
    for module in MODULES:
        keys = set()
        for path in glob.glob(os.path.join(ROOT, "Sources", module, "**/*.swift"), recursive=True):
            for m in PATTERN.finditer(open(path, encoding="utf-8").read()):
                keys.add(unescape(m.group(1) if m.group(1) is not None else m.group(2)))
        strings = {}
        for key in sorted(keys):
            localizations = {}
            for loc in LOCALES:
                value = tables[loc].get(key)
                if value is None:
                    missing.add((loc, key))
                    continue
                localizations[loc] = {"stringUnit": {"state": "translated", "value": value}}
            strings[key] = {"localizations": localizations} if localizations else {}
        catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
        out = os.path.join(ROOT, "Sources", module, "Resources", "Localizable.xcstrings")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(catalog, f, ensure_ascii=False, indent=2, sort_keys=True)
            f.write("\n")
        print(f"{module}: {len(keys)} keys")
    for loc, key in sorted(missing):
        print(f"missing {loc}: {key!r}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
