#!/bin/sh
# setup-hook.sh — встановлює gitleaks pre-commit hook у поточний git-репозиторій.
#
# Використання:
#   sh scripts/setup-hook.sh                    # встановити хук (типово: увімкнено, автовстановлення увімкнено)
#   sh scripts/setup-hook.sh --disable          # встановити, але одразу вимкнути перевірку
#   sh scripts/setup-hook.sh --no-autoinstall   # вимкнути автовстановлення gitleaks
#
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SOURCE_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

TARGET_REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Помилка: поточна тека не є git-репозиторієм (git init спочатку)" >&2
    exit 1
}

HOOKS_DIR="$TARGET_REPO/.git/hooks"
mkdir -p "$HOOKS_DIR"

cp "$SOURCE_DIR/hooks/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"
echo "✓ pre-commit hook встановлено: $HOOKS_DIR/pre-commit"

# Якщо хук встановлюється в ІНШИЙ проєкт (не в цей репозиторій), копіюємо
# також install-gitleaks.sh та .gitleaks.toml, щоб хук працював автономно.
if [ "$TARGET_REPO" != "$SOURCE_DIR" ]; then
    mkdir -p "$TARGET_REPO/scripts"
    if [ ! -f "$TARGET_REPO/scripts/install-gitleaks.sh" ]; then
        cp "$SOURCE_DIR/scripts/install-gitleaks.sh" "$TARGET_REPO/scripts/install-gitleaks.sh"
        chmod +x "$TARGET_REPO/scripts/install-gitleaks.sh"
    fi
    if [ ! -f "$TARGET_REPO/.gitleaks.toml" ]; then
        cp "$SOURCE_DIR/.gitleaks.toml" "$TARGET_REPO/.gitleaks.toml"
    fi
fi

for arg in "$@"; do
    case "$arg" in
        --disable)
            git -C "$TARGET_REPO" config hooks.gitleaks.enable false
            echo "⚠ Перевірку gitleaks вимкнено (hooks.gitleaks.enable=false)"
            ;;
        --no-autoinstall)
            git -C "$TARGET_REPO" config hooks.gitleaks.autoinstall false
            echo "⚠ Автовстановлення gitleaks вимкнено (hooks.gitleaks.autoinstall=false)"
            ;;
        *)
            echo "Невідомий аргумент: $arg (ігнорується)" >&2
            ;;
    esac
done

echo "Готово. Поточні налаштування:"
git -C "$TARGET_REPO" config --get-regexp '^hooks\.gitleaks\.' 2>/dev/null || echo "  (усі опції за замовчуванням: enable=true, autoinstall=true)"
