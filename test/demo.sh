#!/bin/sh
# demo.sh — automated end-to-end demo of the pre-commit hook using a
# Telegram bot token as the example secret.
#
# Steps:
#   1. Create a temporary git repo.
#   2. Install the hook via scripts/setup-hook.sh (this also triggers gitleaks
#      auto-install if it is not present yet).
#   3. Commit a file containing a Telegram bot token -> expect REJECT.
#   4. Commit the same file without the secret -> expect SUCCESS.
#
# Needs network access if gitleaks is not installed yet.
#
# Run:
#   sh test/demo.sh
set -eu

REPO_SRC="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DEMO_DIR="$(mktemp -d -t gitleaks-hook-demo-XXXXXX)"

cleanup() { rm -rf "$DEMO_DIR"; }
trap cleanup EXIT

echo "== 1/4: creating test repo in $DEMO_DIR =="
git init -q "$DEMO_DIR"
cd "$DEMO_DIR"
git config user.email "demo@example.com"
git config user.name "Demo User"

echo
echo "== 2/4: installing pre-commit hook =="
sh "$REPO_SRC/scripts/setup-hook.sh"

echo
echo "== 3/4: commit WITH a Telegram bot token (expect REJECT) =="
cat > config.py <<'PY'
TELEGRAM_BOT_TOKEN = "110201543:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"
PY
git add config.py

set +e
git commit -m "add telegram bot config" >demo_output_1.log 2>&1
COMMIT1_STATUS=$?
set -e

if [ "$COMMIT1_STATUS" -eq 0 ]; then
    echo "❌ DEMO FAILED: commit with a secret went through but should have been blocked!"
    cat demo_output_1.log
    exit 1
fi
echo "✓ Commit correctly rejected. Hook output:"
echo "----------------------------------------"
cat demo_output_1.log
echo "----------------------------------------"

echo
echo "== 4/4: same file WITHOUT the secret (expect SUCCESS) =="
cat > config.py <<'PY'
import os
TELEGRAM_BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
PY
git add config.py

set +e
git commit -m "read telegram bot token from env" >demo_output_2.log 2>&1
COMMIT2_STATUS=$?
set -e

if [ "$COMMIT2_STATUS" -ne 0 ]; then
    echo "❌ DEMO FAILED: commit without secrets was blocked!"
    cat demo_output_2.log
    exit 1
fi
echo "✓ Clean commit passed. Hook output:"
echo "----------------------------------------"
cat demo_output_2.log
echo "----------------------------------------"

echo
echo "== DEMO PASSED: the hook blocks and allows commits as expected =="
