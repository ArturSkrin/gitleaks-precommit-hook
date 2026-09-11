#!/bin/sh
# install-gitleaks.sh — cross-platform gitleaks installer.
#
# Meant to be run "curl | sh" style:
#   curl -sSfL https://raw.githubusercontent.com/ArturSkrin/gitleaks-precommit-hook/main/scripts/install-gitleaks.sh | sh
#
# Or locally after cloning:
#   sh scripts/install-gitleaks.sh
#
# Env vars:
#   GITLEAKS_VERSION      version without "v", e.g. "8.21.2" (default: latest)
#   GITLEAKS_INSTALL_DIR  install target (default: /usr/local/bin or ~/.local/bin)
#
# POSIX sh on purpose (no bashisms) so it runs under dash, ash, git-bash, etc.

set -eu

REPO="gitleaks/gitleaks"
API_BASE="https://api.github.com/repos/${REPO}/releases"
VERSION="${GITLEAKS_VERSION:-latest}"

log() { printf '[install-gitleaks] %s\n' "$1"; }
err() { printf '[install-gitleaks] ERROR: %s\n' "$1" >&2; exit 1; }

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "required command '$1' not found on PATH"
}

need_cmd curl
need_cmd tar
need_cmd mktemp
need_cmd sed
need_cmd grep

# Detect OS
OS_RAW="$(uname -s)"
case "$OS_RAW" in
    Linux*)                 OS="linux" ;;
    Darwin*)                OS="darwin" ;;
    MINGW*|MSYS*|CYGWIN*)   OS="windows" ;;
    *) err "unsupported OS: $OS_RAW" ;;
esac

# Detect arch (with alternate names to match different release naming)
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
    x86_64|amd64)   ARCH_PATTERNS="x64 amd64 x86_64" ;;
    aarch64|arm64)  ARCH_PATTERNS="arm64 aarch64" ;;
    armv7l|armv7)   ARCH_PATTERNS="armv7 arm7" ;;
    armv6l)         ARCH_PATTERNS="armv6 arm6" ;;
    i386|i686)      ARCH_PATTERNS="x32 386 i386" ;;
    *) err "unsupported architecture: $ARCH_RAW" ;;
esac

if [ "$OS" = "windows" ]; then
    EXT="zip"
    BIN_NAME="gitleaks.exe"
else
    EXT="tar.gz"
    BIN_NAME="gitleaks"
fi

# Resolve the release to install
if [ "$VERSION" = "latest" ]; then
    RELEASE_URL="${API_BASE}/latest"
else
    RELEASE_URL="${API_BASE}/tags/v${VERSION}"
fi

log "Fetching release info: $RELEASE_URL"
RELEASE_JSON="$(curl -sSfL -H 'Accept: application/vnd.github+json' "$RELEASE_URL")" \
    || err "GitHub API request failed ($RELEASE_URL). Check your connection."

TAG="$(printf '%s' "$RELEASE_JSON" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
[ -n "$TAG" ] || err "could not parse release tag from GitHub API response"

ASSET_URLS="$(printf '%s' "$RELEASE_JSON" \
    | grep -o '"browser_download_url":[[:space:]]*"[^"]*"' \
    | sed -E 's/.*"(https:\/\/[^"]+)"$/\1/')"
[ -n "$ASSET_URLS" ] || err "no release assets found for $TAG"

# Pick the asset matching OS + arch (no hard-coded filename format)
DOWNLOAD_URL=""
for arch_pat in $ARCH_PATTERNS; do
    candidate="$(printf '%s\n' "$ASSET_URLS" \
        | grep -i "$OS" \
        | grep -i "$arch_pat" \
        | grep -vi 'checksum\|\.sig$\|\.pem$\|\.sbom' \
        | grep -i "\\.${EXT}\$" \
        | head -n1)"
    if [ -n "$candidate" ]; then
        DOWNLOAD_URL="$candidate"
        break
    fi
done

[ -n "$DOWNLOAD_URL" ] || err "no matching binary for OS='$OS' arch='$ARCH_RAW' in release $TAG"

# Download and unpack
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

ARCHIVE="$WORKDIR/gitleaks.$EXT"
log "Downloading $DOWNLOAD_URL"
curl -sSfL -o "$ARCHIVE" "$DOWNLOAD_URL" || err "failed to download $DOWNLOAD_URL"

case "$EXT" in
    tar.gz) tar -xzf "$ARCHIVE" -C "$WORKDIR" ;;
    zip)    need_cmd unzip; unzip -q "$ARCHIVE" -d "$WORKDIR" ;;
esac

BIN_PATH="$(find "$WORKDIR" -type f -name "$BIN_NAME" | head -n1)"
[ -n "$BIN_PATH" ] || err "$BIN_NAME not found in the extracted archive"
chmod +x "$BIN_PATH"

# Choose an install dir on PATH
USE_SUDO=0
if [ -n "${GITLEAKS_INSTALL_DIR:-}" ]; then
    INSTALL_DIR="$GITLEAKS_INSTALL_DIR"
    mkdir -p "$INSTALL_DIR" 2>/dev/null || true
elif [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
elif command -v sudo >/dev/null 2>&1 && [ "$(id -u 2>/dev/null || echo 1000)" != "0" ]; then
    INSTALL_DIR="/usr/local/bin"
    USE_SUDO=1
else
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
fi

TARGET="$INSTALL_DIR/gitleaks"
[ "$OS" = "windows" ] && TARGET="$INSTALL_DIR/gitleaks.exe"

if [ "$USE_SUDO" = "1" ]; then
    log "Installing to $TARGET (via sudo)"
    sudo mkdir -p "$INSTALL_DIR"
    sudo cp "$BIN_PATH" "$TARGET"
    sudo chmod +x "$TARGET"
else
    log "Installing to $TARGET"
    cp "$BIN_PATH" "$TARGET"
    chmod +x "$TARGET"
fi

case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
        log "NOTE: $INSTALL_DIR is not on PATH."
        log "Add to your shell rc:  export PATH=\"$INSTALL_DIR:\$PATH\""
        ;;
esac

log "gitleaks ${TAG} installed: $TARGET"
"$TARGET" version 2>/dev/null || true
