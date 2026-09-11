#!/bin/sh
# install-gitleaks.sh — крос-платформний інсталятор gitleaks.
#
# Призначений для запуску у стилі "curl | sh" (як get.docker.com, rustup.rs тощо):
#
#   curl -sSfL https://raw.githubusercontent.com/<your-user>/<your-repo>/main/scripts/install-gitleaks.sh | sh
#
# Також може виконуватись локально після клонування репозиторію:
#
#   sh scripts/install-gitleaks.sh
#
# Змінні середовища:
#   GITLEAKS_VERSION      - конкретна версія без "v", напр. "8.21.2" (default: latest)
#   GITLEAKS_INSTALL_DIR  - куди встановлювати бінарник (default: /usr/local/bin або ~/.local/bin)
#
# Скрипт навмисно POSIX sh (без bash-специфічних конструкцій), щоб працювати
# в /bin/sh, dash, ash (Alpine), git-bash тощо.

set -eu

REPO="gitleaks/gitleaks"
API_BASE="https://api.github.com/repos/${REPO}/releases"
VERSION="${GITLEAKS_VERSION:-latest}"

log() { printf '[install-gitleaks] %s\n' "$1"; }
err() { printf '[install-gitleaks] ПОМИЛКА: %s\n' "$1" >&2; exit 1; }

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "потрібна утиліта '$1', але вона не знайдена в PATH"
}

need_cmd curl
need_cmd tar
need_cmd mktemp
need_cmd sed
need_cmd grep

# ---------------------------------------------------------------------------
# 1. Визначення ОС
# ---------------------------------------------------------------------------
OS_RAW="$(uname -s)"
case "$OS_RAW" in
    Linux*)                OS="linux" ;;
    Darwin*)                OS="darwin" ;;
    MINGW*|MSYS*|CYGWIN*)   OS="windows" ;;
    *) err "непідтримувана операційна система: $OS_RAW" ;;
esac

# ---------------------------------------------------------------------------
# 2. Визначення архітектури (з альтернативними назвами для пошуку у релізі)
# ---------------------------------------------------------------------------
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
    x86_64|amd64)   ARCH_PATTERNS="x64 amd64 x86_64" ;;
    aarch64|arm64)  ARCH_PATTERNS="arm64 aarch64" ;;
    armv7l|armv7)   ARCH_PATTERNS="armv7 arm7" ;;
    armv6l)         ARCH_PATTERNS="armv6 arm6" ;;
    i386|i686)      ARCH_PATTERNS="x32 386 i386" ;;
    *) err "непідтримувана архітектура: $ARCH_RAW" ;;
esac

if [ "$OS" = "windows" ]; then
    EXT="zip"
    BIN_NAME="gitleaks.exe"
else
    EXT="tar.gz"
    BIN_NAME="gitleaks"
fi

# ---------------------------------------------------------------------------
# 3. Отримання інформації про реліз з GitHub API
# ---------------------------------------------------------------------------
if [ "$VERSION" = "latest" ]; then
    RELEASE_URL="${API_BASE}/latest"
else
    RELEASE_URL="${API_BASE}/tags/v${VERSION}"
fi

log "Отримую інформацію про реліз: $RELEASE_URL"
RELEASE_JSON="$(curl -sSfL -H 'Accept: application/vnd.github+json' "$RELEASE_URL")" \
    || err "не вдалося звернутись до GitHub API ($RELEASE_URL). Перевір інтернет-з'єднання."

TAG="$(printf '%s' "$RELEASE_JSON" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
[ -n "$TAG" ] || err "не вдалося визначити тег релізу з відповіді GitHub API"

ASSET_URLS="$(printf '%s' "$RELEASE_JSON" \
    | grep -o '"browser_download_url":[[:space:]]*"[^"]*"' \
    | sed -E 's/.*"(https:\/\/[^"]+)"$/\1/')"
[ -n "$ASSET_URLS" ] || err "у релізі $TAG не знайдено жодного asset-файлу"

# ---------------------------------------------------------------------------
# 4. Пошук потрібного asset (OS + архітектура), без жорстко зашитого формату імені
# ---------------------------------------------------------------------------
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

[ -n "$DOWNLOAD_URL" ] || err "не знайдено відповідного бінарника для ОС='$OS' архітектура='$ARCH_RAW' у релізі $TAG"

# ---------------------------------------------------------------------------
# 5. Завантаження та розпакування
# ---------------------------------------------------------------------------
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

ARCHIVE="$WORKDIR/gitleaks.$EXT"
log "Завантажую $DOWNLOAD_URL"
curl -sSfL -o "$ARCHIVE" "$DOWNLOAD_URL" || err "не вдалося завантажити $DOWNLOAD_URL"

case "$EXT" in
    tar.gz)
        tar -xzf "$ARCHIVE" -C "$WORKDIR"
        ;;
    zip)
        need_cmd unzip
        unzip -q "$ARCHIVE" -d "$WORKDIR"
        ;;
esac

BIN_PATH="$(find "$WORKDIR" -type f -name "$BIN_NAME" | head -n1)"
[ -n "$BIN_PATH" ] || err "у розпакованому архіві не знайдено файл $BIN_NAME"
chmod +x "$BIN_PATH"

# ---------------------------------------------------------------------------
# 6. Встановлення у теку з PATH
# ---------------------------------------------------------------------------
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
    log "Встановлюю у $TARGET (через sudo)"
    sudo mkdir -p "$INSTALL_DIR"
    sudo cp "$BIN_PATH" "$TARGET"
    sudo chmod +x "$TARGET"
else
    log "Встановлюю у $TARGET"
    cp "$BIN_PATH" "$TARGET"
    chmod +x "$TARGET"
fi

case ":$PATH:" in
    *":$INSTALL_DIR:"*)
        ;;
    *)
        log "УВАГА: $INSTALL_DIR відсутній у PATH."
        log "Додай у ~/.bashrc, ~/.zshrc або аналог:  export PATH=\"$INSTALL_DIR:\$PATH\""
        ;;
esac

log "gitleaks ${TAG} встановлено успішно: $TARGET"
"$TARGET" version 2>/dev/null || true
