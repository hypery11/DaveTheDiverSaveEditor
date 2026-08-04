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

It also enforces the terminology blocklist in docs/TERMINOLOGY.md. Chinese is the one
place where a plausible-looking translation can be wrong in a way review won't catch:
zh-Hant and zh-Hans are separate official localizations of this game, not two scripts of
one, so converting characters between them silently produces the other region's
vocabulary. That is exactly how 鮫人村 and 匠人之火 shipped in zh-Hant.
"""
import json, pathlib, re, sys
from collections import Counter

CATALOG = pathlib.Path(__file__).resolve().parent.parent / "App/Sources/Localizable.xcstrings"
SPEC = re.compile(r"%(?:(\d+)\$)?([@a-zA-Z]+|%)")

# locale -> [(banned term, what to use instead)]. Every entry cites the row key in the
# game's own text sheets that settles it; docs/TERMINOLOGY.md records the reasoning and the
# row key behind each one.
BANNED = {
    "zh-Hant": [
        ("鮫人", "魚人族／魚人村 (scene_MermanVillage) — 鮫人 is the Simplified column"),
        ("匠人之火", "達人的火花 (Owned_ChefFlame) — 匠人之火 is the Simplified column"),
        ("追蹤者", "追蹤人數 (SNS_Grade_Condition_Like)"),
        ("二號店", "分店 (ContentsName_SushiBar_Branch)"),
        ("信任點數", "信賴度 (UIText/trustPoint)"),
        ("信任度", "信賴度 (UIText/trustPoint) — 信任度 is the Simplified column"),
        ("物品欄", "背包 (UI_MVSeedInventory) / 道具 (item_40001) — 物品欄 never appears in the game"),
        ("存檔欄位", "存檔格 — 欄位 means a form field"),
    ],
    "zh-Hans": [
        ("魚人", "鲛人 (scene_MermanVillage) — this locale takes the Simplified column"),
        ("達人的火花", "匠人之火 (Owned_ChefFlame) — this locale takes the Simplified column"),
        ("畸变鱼", "突变鱼 (UI_TravellingMerchant_Title)"),
        ("信赖点数", "信任度 (UIText/trustPoint)"),
        ("2号店", "分店 (ContentsName_SushiBar_Branch) — '2nd store' was ours, not the game's"),
    ],
    "ko": [
        ("신뢰도 포인트", "신뢰도 (UIText/trustPoint) — 신뢰도 already denotes the level"),
        ("2호점", "분점 (ContentsName_SushiBar_Branch)"),
    ],
    "en": [
        ("Merman", "Sea People (scene_MermanVillage) — Merman is only the save field name"),
    ],
}


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
    failures, wrong_terms, locales = [], [], Counter()

    for key, entry in sorted(strings.items()):
        source = entry.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value") or key
        # Only 7 strings carry an explicit "en" unit; for the rest the KEY is the English
        # source, so the en blocklist has to be checked against the key as well or it
        # would silently pass over almost the whole catalog.
        for term, fix in BANNED.get("en", ()):
            if term in source:
                wrong_terms.append(f"  [en] {key!r}\n      uses {term!r} — use {fix}\n      source: {source!r}")
        for locale, loc in sorted(entry.get("localizations", {}).items()):
            value = loc.get("stringUnit", {}).get("value")
            if value is None:
                continue
            locales[locale] += 1
            for problem in problems(source, value):
                failures.append(f"  [{locale}] {key!r}\n      {problem}\n      source: {source!r}\n      value:  {value!r}")
            for term, fix in BANNED.get(locale, ()):
                if term in value:
                    wrong_terms.append(f"  [{locale}] {key!r}\n      uses {term!r} — use {fix}\n      value:  {value!r}")

    print(f"{len(strings)} strings; translations per locale: "
          + ", ".join(f"{k}={v}" for k, v in sorted(locales.items())))

    if failures:
        print(f"\n{len(failures)} format-specifier problem(s) — these would crash the app:\n")
        print("\n".join(failures))
        return 1
    print("Format specifiers OK in every locale.")

    if wrong_terms:
        print(f"\n{len(wrong_terms)} term(s) that don't match the game's own localization:\n")
        print("\n".join(wrong_terms))
        return 1
    print("Terminology OK — see docs/TERMINOLOGY.md.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
