#!/bin/sh
# setup-hook.sh — install the gitleaks pre-commit hook into a git repo.
#
# Usage:
#   sh scripts/setup-hook.sh                    # install (defaults: enabled, autoinstall on)
#   sh scripts/setup-hook.sh --disable          # install but disable the check
#   sh scripts/setup-hook.sh --no-autoinstall   # install but disable gitleaks auto-install
#
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SOURCE_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

TARGET_REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: current directory is not a git repository (run 'git init' first)" >&2
    exit 1
}

HOOKS_DIR="$TARGET_REPO/.git/hooks"
mkdir -p "$HOOKS_DIR"

cp "$SOURCE_DIR/hooks/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"
echo "✓ pre-commit hook installed: $HOOKS_DIR/pre-commit"

# When installing into a different project, also copy the installer and config
# so the hook is self-contained there.
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
            echo "⚠ gitleaks check disabled (hooks.gitleaks.enable=false)"
            ;;
        --no-autoinstall)
            git -C "$TARGET_REPO" config hooks.gitleaks.autoinstall false
            echo "⚠ gitleaks auto-install disabled (hooks.gitleaks.autoinstall=false)"
            ;;
        *)
            echo "Unknown argument: $arg (ignored)" >&2
            ;;
    esac
done

echo "Done. Current settings:"
git -C "$TARGET_REPO" config --get-regexp '^hooks\.gitleaks\.' 2>/dev/null \
    || echo "  (all defaults: enable=true, autoinstall=true)"
