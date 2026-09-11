#!/bin/sh
# Install the pre-commit hook into the current repo's .git/hooks.
set -eu
src="$(cd "$(dirname "$0")/.." && pwd)"
repo="$(git rev-parse --show-toplevel)"
cp "$src/hooks/pre-commit" "$repo/.git/hooks/pre-commit"
chmod +x "$repo/.git/hooks/pre-commit"
# When installing into another repo, ship the installer and config too.
if [ "$repo" != "$src" ]; then
    mkdir -p "$repo/scripts"
    cp "$src/scripts/install-gitleaks.sh" "$repo/scripts/install-gitleaks.sh"
    [ -f "$repo/.gitleaks.toml" ] || cp "$src/.gitleaks.toml" "$repo/.gitleaks.toml"
fi
echo "hook installed: $repo/.git/hooks/pre-commit"
