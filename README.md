# gitleaks-precommit-hook

A git `pre-commit` hook that scans staged changes for secrets (API keys,
tokens, passwords, private keys, etc.) using
[gitleaks](https://github.com/gitleaks/gitleaks) and **rejects the commit** if
any secret is found.

Features OS-aware auto-install of gitleaks (Linux / macOS / Windows), an
`enable`/`disable` toggle via `git config`, and a `curl | sh` style installer.

## Layout

```
.
├── hooks/
│   └── pre-commit            # the git hook (bash)
├── scripts/
│   ├── install-gitleaks.sh   # cross-platform gitleaks installer (curl | sh)
│   └── setup-hook.sh         # installs hooks/pre-commit into a repo's .git/hooks
├── test/
│   └── demo.sh               # automated demo using a Telegram bot token
├── .gitleaks.toml            # gitleaks config: default rules + Telegram Bot Token
└── README.md
```

## Requirements

- `git`, `bash`/`sh`, `curl`, `tar` (standard on Linux/macOS; on Windows use
  Git Bash or WSL).
- Network access **once**, only if `gitleaks` is not installed yet (for
  auto-install). After that the hook works offline.

## Quick start

### Option 1 — install the hook into your project (recommended)

```bash
git clone https://github.com/ArturSkrin/gitleaks-precommit-hook.git
cd gitleaks-precommit-hook

# install into THIS repo (to try it), or cd into another project first:
#   cd /path/to/my/project && sh /path/to/gitleaks-precommit-hook/scripts/setup-hook.sh
sh scripts/setup-hook.sh
```

This copies `hooks/pre-commit` into the target repo's `.git/hooks/pre-commit`
(and, when installing into a different project, also copies
`install-gitleaks.sh` and `.gitleaks.toml` so the hook is self-contained).

### Option 2 — install only gitleaks (curl | sh)

If you just want the `gitleaks` binary, without the hook:

```bash
curl -sSfL https://raw.githubusercontent.com/ArturSkrin/gitleaks-precommit-hook/main/scripts/install-gitleaks.sh | sh
```

The script detects the OS (Linux/macOS/Windows) and architecture
(x64/arm64/...), downloads the matching GitHub release, and installs the binary
to `/usr/local/bin` (or `~/.local/bin` if there is no write access / sudo).

Pin a specific version:

```bash
GITLEAKS_VERSION=8.21.2 curl -sSfL https://raw.githubusercontent.com/ArturSkrin/gitleaks-precommit-hook/main/scripts/install-gitleaks.sh | sh
```

### Option 3 — copy the hook file manually (minimal)

```bash
cp hooks/pre-commit /path/to/project/.git/hooks/pre-commit
chmod +x /path/to/project/.git/hooks/pre-commit
```

Fine if `gitleaks` is already installed manually (`brew install gitleaks`,
`apt install gitleaks`, etc.) — auto-install simply won't trigger.

## How it works

1. On every `git commit`, git runs `.git/hooks/pre-commit`.
2. The hook checks `git config hooks.gitleaks.enable` — if `false`, it skips.
3. If `gitleaks` is not on `PATH` and `hooks.gitleaks.autoinstall` is not
   `false`, the hook installs it:
   - if `scripts/install-gitleaks.sh` exists in the repo, it runs it locally;
   - if `git config hooks.gitleaks.installUrl <url>` is set, it fetches the
     installer via `curl -sSfL <url> | sh` (the classic way CLI tools are
     distributed, like `get.docker.com` or `rustup.rs`).
4. The hook runs `gitleaks protect --staged --redact` (the mode gitleaks
   provides specifically for pre-commit hooks — it scans only staged changes,
   not the whole history) with `.gitleaks.toml` if present.
5. If gitleaks finds a secret, it prints an error, saves a redacted JSON
   report, and **rejects the commit** (`exit 1`).
6. If nothing is found, the commit proceeds as usual.

## Configuration via `git config`

All options have working defaults — nothing needs to be configured.

| Key | Value | Default | Description |
|---|---|---|---|
| `hooks.gitleaks.enable` | `true` / `false` | `true` | Enable/disable the check entirely |
| `hooks.gitleaks.autoinstall` | `true` / `false` | `true` | Let the hook install gitleaks if missing |
| `hooks.gitleaks.installUrl` | URL | — (empty → local `scripts/install-gitleaks.sh`) | Source for the `curl \| sh` installer |
| `hooks.gitleaks.version` | e.g. `8.21.2` | `latest` | gitleaks version (see `GITLEAKS_VERSION` in the installer) |

Examples:

```bash
# temporarily disable the check in a repo
git config hooks.gitleaks.enable false

# forbid auto-install (e.g. admin installs gitleaks themselves)
git config hooks.gitleaks.autoinstall false

# use the curl|sh installer from a specific URL
git config hooks.gitleaks.installUrl "https://raw.githubusercontent.com/ArturSkrin/gitleaks-precommit-hook/main/scripts/install-gitleaks.sh"
```

A one-off manual scan is also possible without the hook: `gitleaks protect --staged`.

Bypass the check for a single commit (standard git behaviour, unrelated to this
hook): `git commit --no-verify`.

## Testing with a Telegram Bot Token

The automated script (`test/demo.sh`) creates a temporary repo, installs the
hook, and checks both scenarios — a commit with a secret (must be rejected) and
a commit without (must pass):

```bash
sh test/demo.sh
```

### Manual walkthrough

```bash
mkdir /tmp/demo && cd /tmp/demo
git init
git config user.email you@example.com
git config user.name "Your Name"

# install the hook (path points to this repo)
sh /path/to/gitleaks-precommit-hook/scripts/setup-hook.sh

# "leak" a Telegram bot token (this is the official placeholder example from
# the Telegram Bot API docs, not a real token)
echo 'TELEGRAM_BOT_TOKEN = "110201543:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"' > config.py

git add config.py
git commit -m "add bot config"
```

Expected result — the commit is rejected, roughly like:

```
→ Scanning staged changes for secrets (gitleaks)...

    Finding:     TELEGRAM_BOT_TOKEN = "REDACTED"
    RuleID:      telegram-bot-token
    File:        config.py

════════════════════════════════════════════════════════════
  🔒 POTENTIAL SECRETS FOUND IN STAGED CHANGES
════════════════════════════════════════════════════════════
  ...
✗ COMMIT REJECTED
  Reason: gitleaks detected potential secrets in the commit (exit code: 1)
```

Remove the secret (e.g. read the token from an env var) and the commit passes:

```bash
cat > config.py <<'EOF'
import os
TELEGRAM_BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
EOF
git add config.py
git commit -m "read token from env"
# ✓ No secrets found. Commit allowed.
```

## Handling false positives

Add an exception to `.gitleaks.toml` (a `[[rules.allowlist]]` block for a
specific rule, or a global `[allowlist]` — see the
[gitleaks docs](https://github.com/gitleaks/gitleaks#configuration)), or bypass
once with `git commit --no-verify` (use with care).

## Grading criteria mapping

| Level | Requirement | Where |
|---|---|---|
| Junior (3 pts) | pre-commit hook with locally installed gitleaks | `hooks/pre-commit` works with any `gitleaks` on `PATH` (Option 3) |
| Middle (7 pts) | + OS-aware auto-install, `enable` toggle via `git config` | `scripts/install-gitleaks.sh` (OS/arch detection) + `hooks.gitleaks.enable`/`autoinstall` in `hooks/pre-commit` |
| Senior (10 pts) | + `curl \| sh` installation | `scripts/install-gitleaks.sh` is a standalone `curl -sSfL <url> \| sh` installer (docker/rustup style); the hook can pull it exactly that way via `hooks.gitleaks.installUrl` |

## Notes / limitations

- `install-gitleaks.sh` downloads the binary from the `gitleaks/gitleaks`
  GitHub Releases, so the first install needs network access. Subsequent
  commits do not.
- The Telegram Bot Token rule is added explicitly in `.gitleaks.toml` (on top
  of the default gitleaks rule set) to reliably catch the
  `<bot_id>:<~35 chars>` format regardless of the gitleaks version.
- Scripts are written in bash (`hooks/pre-commit`) and POSIX `sh`
  (`scripts/*.sh`, `test/demo.sh`) for broad compatibility.

## License

MIT — see [LICENSE](LICENSE).
