#!/usr/bin/env bash
# demo.sh — автоматична end-to-end демонстрація роботи pre-commit hook
# на прикладі Telegram Bot Token.
#
# Що робить:
#   1. Створює тимчасовий git-репозиторій.
#   2. Встановлює туди хук через scripts/setup-hook.sh (це також запустить
#      автовстановлення gitleaks, якщо він ще не встановлений на машині).
#   3. Комітить файл із "витоком" Telegram bot token -> очікує ВІДМОВУ.
#   4. Комітить той самий файл без секрету -> очікує УСПІХ.
#
# Потрібен інтернет-доступ, якщо gitleaks ще не встановлено на машині.
#
# Запуск:
#   sh test/demo.sh

set -euo pipefail

REPO_SRC="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="$(mktemp -d -t gitleaks-hook-demo-XXXXXX)"

cleanup() { rm -rf "$DEMO_DIR"; }
trap cleanup EXIT

echo "== 1/4: створюю тестовий репозиторій у $DEMO_DIR =="
git init -q "$DEMO_DIR"
cd "$DEMO_DIR"
git config user.email "demo@example.com"
git config user.name "Demo User"

echo
echo "== 2/4: встановлюю pre-commit hook =="
sh "$REPO_SRC/scripts/setup-hook.sh"

echo
echo "== 3/4: коміт ІЗ Telegram bot token (очікується ВІДХИЛЕННЯ) =="
cat > config.py <<'EOF'
TELEGRAM_BOT_TOKEN = "110201543:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"
EOF
git add config.py

set +e
git commit -m "add telegram bot config" >demo_output_1.log 2>&1
COMMIT1_STATUS=$?
set -e

if [ "$COMMIT1_STATUS" -eq 0 ]; then
    echo "❌ ПОМИЛКА ДЕМО: коміт із секретом пройшов, хоча мав бути заблокований!"
    cat demo_output_1.log
    exit 1
fi
echo "✓ Коміт коректно відхилено. Вивід хука:"
echo "----------------------------------------"
cat demo_output_1.log
echo "----------------------------------------"

echo
echo "== 4/4: той самий файл БЕЗ секрету (очікується УСПІХ) =="
cat > config.py <<'EOF'
import os
TELEGRAM_BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
EOF
git add config.py

set +e
git commit -m "read telegram bot token from env" >demo_output_2.log 2>&1
COMMIT2_STATUS=$?
set -e

if [ "$COMMIT2_STATUS" -ne 0 ]; then
    echo "❌ ПОМИЛКА ДЕМО: коміт без секретів був заблокований!"
    cat demo_output_2.log
    exit 1
fi
echo "✓ Коміт без секретів успішно пройшов. Вивід хука:"
echo "----------------------------------------"
cat demo_output_2.log
echo "----------------------------------------"

echo
echo "== ДЕМОНСТРАЦІЯ ЗАВЕРШЕНА УСПІШНО: хук коректно блокує та пропускає коміти =="
