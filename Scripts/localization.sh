#!/bin/bash
#
# Keeps Localization/Localizable.xcstrings in step with the source code.
#
#   Scripts/localization.sh sync      compile with string extraction, then add new keys to the
#                                      catalog and mark keys the code no longer uses as stale
#   Scripts/localization.sh compile DIR
#                                      write <lang>.lproj/Localizable.strings(dict) into DIR —
#                                      what Scripts/make-app.sh puts in Contents/Resources
#
# The keys come from the Swift compiler itself (-emit-localized-strings), the same mechanism
# Xcode uses, so interpolations get the right format specifiers (%lld for integers, %@ for
# strings) without anyone typing them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT/Localization/Localizable.xcstrings"

case "${1:-}" in
  sync)
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"' EXIT
    echo "==> Extracting strings"
    swift build --package-path "$ROOT" --build-path "$WORK/build" \
      -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$WORK/strings" >/dev/null
    if [[ ! -f "$CATALOG" ]]; then
      echo '{"sourceLanguage":"en","strings":{},"version":"1.0"}' > "$CATALOG"
    fi
    echo "==> Syncing $(basename "$CATALOG")"
    xcrun xcstringstool sync "$CATALOG" --stringsdata "$WORK"/strings/*.stringsdata
    python3 - "$CATALOG" <<'PY'
import json, sys
catalog = json.load(open(sys.argv[1]))
strings = catalog["strings"]
stale = sum(1 for v in strings.values() if v.get("extractionState") == "stale")
print(f"    {len(strings)} keys, {stale} stale")
PY
    ;;
  compile)
    OUTPUT="${2:?usage: localization.sh compile OUTPUT_DIR}"
    mkdir -p "$OUTPUT"
    xcrun xcstringstool compile "$CATALOG" --output-directory "$OUTPUT" >/dev/null
    ;;
  *)
    echo "usage: $0 sync | compile OUTPUT_DIR" >&2
    exit 1
    ;;
esac
