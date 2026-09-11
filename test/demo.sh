#!/bin/sh
# Quick check: hook must reject a Telegram token and allow a clean file.
set -eu
src="$(cd "$(dirname "$0")/.." && pwd)"
dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
cd "$dir"; git init -q; git config user.email t@t; git config user.name t
sh "$src/scripts/setup-hook.sh"

echo 'TOKEN = "110201543:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"' > c.py
git add c.py
if git commit -m secret >/dev/null 2>&1; then echo "FAIL: secret committed"; exit 1; fi
echo "OK: secret blocked"

echo 'import os; TOKEN = os.environ["TOKEN"]' > c.py
git add c.py
if git commit -m clean >/dev/null 2>&1; then echo "OK: clean allowed"; else echo "FAIL: clean blocked"; exit 1; fi
