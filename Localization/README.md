# Localization

Brewwery's interface text lives in one String Catalog, `Localizable.xcstrings`. English is the
source language; the keys are the English strings as they appear in the code.

## Languages

| Language | Code | Status |
| --- | --- | --- |
| English | `en` | Source |
| German | `de` | Shipped |
| French | `fr` | Planned for the next version |
| Spanish | `es` | Planned for the next version |
| Portuguese | `pt` | Planned for the next version |

Dutch, Danish, Polish, Japanese, Korean and Hebrew — the other languages of brewwery.com — may
follow later.

A language ships only when every key is translated. `CFBundleLocalizations` in
`Packaging/Info.plist` lists the shipped languages and nothing else: a language listed there
makes macOS show the menus and system dialogs in it, and a half-translated app would then mix
two languages.

## Workflow

1. **After changing interface text**, run `Scripts/localization.sh sync`. It builds the app
   with the compiler's string extraction and adds new keys to the catalog. Keys the code no
   longer uses are marked stale.
2. **To translate**, write a JSON table for the language, named after its code (`fr.json`),
   and run `Scripts/merge-translations.py fr.json`. The script checks every placeholder and
   every plural form (CLDR categories: French, Spanish and Portuguese use `one`, `many` and
   `other`) and writes nothing if a check fails. The format is described at the top of the
   script.
3. **To ship a language**, add its code to `CFBundleLocalizations` and check the layout with
   `SHOTS_LANGUAGE=fr Scripts/screenshots.sh`. Translations run longer than English, so look
   for truncated buttons and table columns.

`Scripts/make-app.sh` compiles the catalog into `<lang>.lproj` folders in the app bundle.

## Writing localizable code

- Labels in the design system take `LocalizedStringResource`, so a string literal passed to
  them is extracted automatically.
- In `String` contexts, use `String(localized:)`.
- Show data — package names, paths, command output — with `Text(verbatim:)` so it is never
  looked up.
- Write whole sentences with interpolation (`"Brewwery will run \(command)."`) rather than
  joining fragments; word order differs between languages.
- Give an optional label its type up front. The compiler does not extract the second branch
  of `condition ? "a" : "b"` when the result is converted to `LocalizedStringResource?`.
