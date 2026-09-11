# gitleaks-precommit-hook

A git pre-commit hook that blocks commits containing secrets, using
[gitleaks](https://github.com/gitleaks/gitleaks). Installs gitleaks
automatically (per OS) if it is missing.

## Install

```
git clone https://github.com/ArturSkrin/gitleaks-precommit-hook.git
cd gitleaks-precommit-hook
sh scripts/setup-hook.sh
```

Or just the binary (curl | sh):

```
curl -sSfL https://raw.githubusercontent.com/ArturSkrin/gitleaks-precommit-hook/no-ai-slop/scripts/install-gitleaks.sh | sh
```

## Usage

On `git commit` the hook scans staged changes with `gitleaks protect --staged`.
If a secret is found, the commit is rejected.

```
git config hooks.gitleaks.enable false        # disable the check
git config hooks.gitleaks.autoinstall false   # don't auto-install gitleaks
```

Bypass a single commit: `git commit --no-verify`.

## Test

```
sh test/demo.sh
```

Commits a file with a Telegram bot token (rejected), then without it (allowed).

## Files

- `hooks/pre-commit` — the hook
- `scripts/install-gitleaks.sh` — OS-aware installer (curl | sh)
- `scripts/setup-hook.sh` — installs the hook
- `.gitleaks.toml` — default rules + Telegram token rule
