#!/usr/bin/env python3
"""Merges translation tables into Localization/Localizable.xcstrings.

    Scripts/merge-translations.py de.json fr.json …

Each table is a JSON object for one language, named after it (`de.json`), mapping an English
key to either a string or, for keys with a single %lld, an object of CLDR plural forms:

    {"Refresh": "Aktualisieren",
     "%lld casks": {"one": "%lld Cask", "other": "%lld Casks"}}

Every translation is checked before it is written: it must use the same placeholders as the
key (%@, %lld, in any order when positional), and plural forms must be ones the language has.
Nothing is written if any table fails.
"""
import json
import pathlib
import re
import sys

CATALOG = pathlib.Path(__file__).resolve().parent.parent / "Localization" / "Localizable.xcstrings"

PLURAL_CATEGORIES = {
    "en": {"one", "other"}, "de": {"one", "other"}, "nl": {"one", "other"}, "da": {"one", "other"},
    "fr": {"one", "many", "other"}, "es": {"one", "many", "other"}, "pt": {"one", "many", "other"},
    "pl": {"one", "few", "many", "other"}, "he": {"one", "two", "other"},
    "ja": {"other"}, "ko": {"other"},
}

PLACEHOLDER = re.compile(r"%(?:(\d+)\$)?(@|lld|d|ld)")


def placeholders(text):
    """The placeholder types in argument order, honouring %1$@-style positions."""
    found = []
    sequential = 0
    for match in PLACEHOLDER.finditer(text):
        position, kind = match.groups()
        kind = "lld" if kind in ("lld", "ld", "d") else "@"
        if position:
            index = int(position) - 1
        else:
            index = sequential
            sequential += 1
        found.append((index, kind))
    return sorted(set(found))


def check(language, key, value, errors):
    expected = placeholders(key)
    forms = value.items() if isinstance(value, dict) else [("value", value)]
    if isinstance(value, dict):
        unknown = set(value) - PLURAL_CATEGORIES[language]
        if unknown:
            errors.append(f"{language}: {key!r}: plural forms {sorted(unknown)} do not exist in {language}")
        if "other" not in value:
            errors.append(f"{language}: {key!r}: plural forms need 'other'")
        if key.count("%lld") != 1:
            errors.append(f"{language}: {key!r}: plural forms need exactly one %lld in the key")
    for form, text in forms:
        if not isinstance(text, str) or not text.strip():
            errors.append(f"{language}: {key!r} ({form}): empty translation")
            continue
        actual = placeholders(text)
        # A plural form may drop the number ("one" → "a cask") but never invent one.
        if isinstance(value, dict) and form != "other":
            if not set(actual) <= set(expected):
                errors.append(f"{language}: {key!r} ({form}): placeholders {actual} not in {expected}")
        elif actual != expected:
            errors.append(f"{language}: {key!r} ({form}): placeholders {actual} ≠ {expected}")


def unit(text):
    return {"stringUnit": {"state": "translated", "value": text}}


def main(paths):
    catalog = json.loads(CATALOG.read_text())
    strings = catalog["strings"]
    errors, tables = [], []

    for path in map(pathlib.Path, paths):
        language = path.stem
        if language not in PLURAL_CATEGORIES:
            errors.append(f"{path}: unknown language {language!r}")
            continue
        table = json.loads(path.read_text())
        for key, value in table.items():
            if key not in strings:
                errors.append(f"{language}: {key!r} is not in the catalog")
                continue
            check(language, key, value, errors)
        tables.append((language, table))

    if errors:
        print("\n".join(errors), file=sys.stderr)
        print(f"\n{len(errors)} problem(s); nothing written.", file=sys.stderr)
        return 1

    for language, table in tables:
        for key, value in table.items():
            localizations = strings[key].setdefault("localizations", {})
            if isinstance(value, dict):
                localizations[language] = {
                    "variations": {"plural": {form: unit(text) for form, text in value.items()}}
                }
            else:
                localizations[language] = unit(value)

    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n")

    languages = sorted(PLURAL_CATEGORIES)
    for language in languages:
        if language == "en":
            continue
        missing = [k for k, v in strings.items() if language not in v.get("localizations", {})]
        print(f"{language}: {len(strings) - len(missing)}/{len(strings)} translated")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
