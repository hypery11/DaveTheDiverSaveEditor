#!/usr/bin/env python3
"""Validate the String Catalog. Run by CI on every push and PR.

The check that matters is format specifiers. A translation that drops or reorders %@ /
%lld doesn't read badly — it crashes the app at runtime, and it does so only in that one
language, which is exactly the kind of bug a maintainer who doesn't speak the language
will never hit. So it's checked mechanically rather than by review.

Rules:
  * every specifier in the source must appear in the translation, same count and types;
  * a translation may reorder them ONLY by switching to positional form (%1$@, %2$lld),
    and then the indices must match the source types.
"""
import json, pathlib, re, sys
from collections import Counter

CATALOG = pathlib.Path(__file__).resolve().parent.parent / "App/Sources/Localizable.xcstrings"
SPEC = re.compile(r"%(?:(\d+)\$)?([@a-zA-Z]+|%)")


def specs(text):
    """[(position or None, conversion)] for each real specifier; %% is an escape, not one."""
    return [(m.group(1), m.group(2)) for m in SPEC.finditer(text) if m.group(2) != "%"]


def problems(source, translation):
    src = [c for _, c in specs(source)]
    tr = specs(translation)
    if not src and not tr:
        return []
    positions = [p for p, _ in tr if p]

    if positions:
        if len(positions) != len(tr):
            return ["mixes positional (%1$@) and non-positional (%@) specifiers"]
        idx = sorted(int(p) for p in positions)
        if idx != list(range(1, len(src) + 1)):
            return [f"positional indices {idx} don't cover 1..{len(src)}"]
        wrong = [f"%{p}$ should be {src[int(p)-1]}, got {c}" for p, c in tr if src[int(p) - 1] != c]
        return wrong
    if Counter(src) != Counter(c for _, c in tr):
        return [f"specifiers differ: source has {src or 'none'}, translation has {[c for _, c in tr] or 'none'}"]
    if len(src) > 1 and src != [c for _, c in tr]:
        return ["specifier order differs — use positional form (%1$@, %2$@) so values still bind correctly"]
    return []


def main():
    cat = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = cat["strings"]
    failures, locales = [], Counter()

    for key, entry in sorted(strings.items()):
        source = entry.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value") or key
        for locale, loc in sorted(entry.get("localizations", {}).items()):
            value = loc.get("stringUnit", {}).get("value")
            if value is None:
                continue
            locales[locale] += 1
            for problem in problems(source, value):
                failures.append(f"  [{locale}] {key!r}\n      {problem}\n      source: {source!r}\n      value:  {value!r}")

    print(f"{len(strings)} strings; translations per locale: "
          + ", ".join(f"{k}={v}" for k, v in sorted(locales.items())))

    if failures:
        print(f"\n{len(failures)} format-specifier problem(s) — these would crash the app:\n")
        print("\n".join(failures))
        return 1
    print("Format specifiers OK in every locale.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
