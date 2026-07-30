#!/usr/bin/env python3
"""Convert the String Catalog to/from CSV, for translators who'd rather use a spreadsheet.

The canonical, lossless route is Apple's own XLIFF tooling:

    xcodebuild -exportLocalizations -project App/DaveTheDiverSaveEditor.xcodeproj \
      -scheme DaveTheDiverSaveEditor -localizationPath loc -exportLanguage <lang>
    # translate the .xcloc in Poedit / Crowdin / any CAT tool, then
    xcodebuild -importLocalizations ... -localizationPath loc/<lang>.xcloc

This script exists for the other kind of contributor: a native-speaking player with a
spreadsheet and no Xcode. It is deliberately narrow — it only ever writes translation
values, never keys, states or structure.

    Scripts/loc_csv.py export zh-Hant translations.csv
    Scripts/loc_csv.py import zh-Hant translations.csv
"""
import csv, json, pathlib, sys

CATALOG = pathlib.Path(__file__).resolve().parent.parent / "App/Sources/Localizable.xcstrings"
COLUMNS = ["key", "english", "translation", "note"]


def load():
    return json.loads(CATALOG.read_text(encoding="utf-8"))


def unit(entry, locale):
    return entry.get("localizations", {}).get(locale, {}).get("stringUnit", {})


def export(locale, out):
    cat = load()
    rows = []
    for key, entry in sorted(cat["strings"].items()):
        if entry.get("shouldTranslate") is False:
            continue
        rows.append({
            "key": key,
            # The source language has no table of its own — the key *is* the English text.
            "english": unit(entry, "en").get("value") or key,
            "translation": unit(entry, locale).get("value", ""),
            "note": entry.get("comment", ""),
        })
    with open(out, "w", newline="", encoding="utf-8-sig") as f:   # BOM: Excel opens UTF-8 correctly
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        w.writerows(rows)
    done = sum(1 for r in rows if r["translation"])
    print(f"{out}: {len(rows)} strings, {done} already translated, {len(rows)-done} to do")


def import_(locale, src):
    cat = load()
    with open(src, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    missing = [c for c in ("key", "translation") if rows and c not in rows[0]]
    if missing:
        sys.exit(f"CSV is missing column(s): {', '.join(missing)}")

    changed = unknown = 0
    for row in rows:
        key, value = row["key"], (row["translation"] or "").strip()
        if not value:
            continue
        entry = cat["strings"].get(key)
        if entry is None:
            unknown += 1
            continue
        if unit(entry, locale).get("value") == value:
            continue
        entry.setdefault("localizations", {})[locale] = {
            "stringUnit": {"state": "translated", "value": value}
        }
        changed += 1

    CATALOG.write_text(json.dumps(cat, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{locale}: updated {changed} string(s)" + (f", ignored {unknown} unknown key(s)" if unknown else ""))
    print("Now run Scripts/check_catalog.py to confirm the format specifiers still line up.")


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] not in ("export", "import"):
        sys.exit(__doc__)
    (export if sys.argv[1] == "export" else import_)(sys.argv[2], sys.argv[3])
