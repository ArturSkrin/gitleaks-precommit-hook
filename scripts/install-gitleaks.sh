#!/bin/sh
# Install gitleaks for the current OS/arch. Usable as: curl -sSfL <url> | sh
set -eu

version="${GITLEAKS_VERSION:-latest}"
api="https://api.github.com/repos/gitleaks/gitleaks/releases"

case "$(uname -s)" in
    Linux*)  os=linux ;;
    Darwin*) os=darwin ;;
    *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
    x86_64|amd64)  arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

[ "$version" = latest ] && url="$api/latest" || url="$api/tags/v$version"

asset="$(curl -sSfL "$url" \
    | grep -o '"browser_download_url": *"[^"]*"' \
    | sed 's/.*"\(https[^"]*\)"/\1/' \
    | grep -i "${os}_${arch}\.tar\.gz$" | head -n1)"
[ -n "$asset" ] || { echo "no release asset for ${os}_${arch}" >&2; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo "downloading $asset"
curl -sSfL "$asset" | tar -xz -C "$tmp"

if [ -w /usr/local/bin ]; then
    install -m 0755 "$tmp/gitleaks" /usr/local/bin/gitleaks
    dest=/usr/local/bin/gitleaks
elif command -v sudo >/dev/null 2>&1; then
    sudo install -m 0755 "$tmp/gitleaks" /usr/local/bin/gitleaks
    dest=/usr/local/bin/gitleaks
else
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$tmp/gitleaks" "$HOME/.local/bin/gitleaks"
    dest="$HOME/.local/bin/gitleaks"
fi
echo "installed: $dest"
"$dest" version
