# gitleaks-precommit-hook

Git `pre-commit` хук, який перевіряє застейджені зміни на наявність секретів
(API-ключі, токени, паролі, приватні ключі тощо) за допомогою
[gitleaks](https://github.com/gitleaks/gitleaks) і **відхиляє коміт**, якщо
секрет знайдено.

Реалізовано з автоматичним встановленням gitleaks залежно від операційної
системи (Linux / macOS / Windows), опцією `enable`/`disable` через
`git config`, та інсталятором у форматі `curl | sh`.

## Структура репозиторію

```
.
├── hooks/
│   └── pre-commit            # сам git-хук (bash)
├── scripts/
│   ├── install-gitleaks.sh   # крос-платформний інсталятор gitleaks (curl | sh)
│   └── setup-hook.sh         # встановлює hooks/pre-commit у .git/hooks/ поточного репо
├── test/
│   └── demo.sh                # автоматична демонстрація на прикладі Telegram bot token
├── .gitleaks.toml             # конфіг gitleaks: стандартні правила + Telegram Bot Token
└── README.md
```

## Вимоги

- `git`, `bash`/`sh`, `curl`, `tar` (стандартно є в Linux/macOS; у Windows —
  через Git Bash/WSL).
- Інтернет-доступ **лише один раз**, якщо `gitleaks` ще не встановлений на
  машині (для автовстановлення). Далі хук працює офлайн.

## Швидкий старт

### Варіант 1 — встановити хук у свій проєкт (рекомендовано)

```bash
git clone https://github.com/<your-user>/<your-repo>.git
cd <your-repo>

# встановити хук у ЦЕЙ Ж репозиторій (для тесту) або перейти в інший проєкт:
#   cd /шлях/до/мого/проєкту && sh /шлях/до/gitleaks-precommit-hook/scripts/setup-hook.sh
sh scripts/setup-hook.sh
```

Це скопіює `hooks/pre-commit` у `.git/hooks/pre-commit` цільового репозиторію
(і, якщо хук встановлюється в інший проєкт, — також `install-gitleaks.sh` та
`.gitleaks.toml`, щоб хук працював автономно).

### Варіант 2 — встановити лише gitleaks (curl | sh)

Якщо потрібен просто бінарник `gitleaks` в системі, без хука:

```bash
curl -sSfL https://raw.githubusercontent.com/<your-user>/<your-repo>/main/scripts/install-gitleaks.sh | sh
```

Скрипт сам визначає ОС (Linux/macOS/Windows) та архітектуру (x64/arm64/...),
завантажує відповідний реліз з GitHub і встановлює бінарник у
`/usr/local/bin` (або `~/.local/bin`, якщо немає прав запису/sudo).

Версію можна зафіксувати:

```bash
GITLEAKS_VERSION=8.21.2 curl -sSfL https://raw.githubusercontent.com/<your-user>/<your-repo>/main/scripts/install-gitleaks.sh | sh
```

### Варіант 3 — просто скопіювати файл хука вручну (мінімальний, junior-рівень)

```bash
cp hooks/pre-commit /шлях/до/проєкту/.git/hooks/pre-commit
chmod +x /шлях/до/проєкту/.git/hooks/pre-commit
```

Підходить, якщо `gitleaks` уже встановлений локально вручну
(`brew install gitleaks`, `apt install gitleaks`, і т.д.) — автовстановлення
в такому разі просто не спрацює, бо бінарник вже є в PATH.

## Як це працює

1. При кожному `git commit` git автоматично запускає `.git/hooks/pre-commit`.
2. Хук перевіряє `git config hooks.gitleaks.enable` — якщо `false`, перевірка
   пропускається.
3. Якщо `gitleaks` не знайдено в `PATH`, а `hooks.gitleaks.autoinstall` не
   вимкнено (`false`), хук автоматично встановлює його:
   - якщо в репозиторії є `scripts/install-gitleaks.sh` — виконує його локально;
   - якщо задано `git config hooks.gitleaks.installUrl <url>` — тягне
     інсталятор через `curl -sSfL <url> | sh` (класичний спосіб дистрибуції
     CLI-тулзів, як `get.docker.com`, `rustup.rs` тощо).
4. Хук запускає `gitleaks protect --staged --redact` (режим, спеціально
   призначений gitleaks для pre-commit hooks — перевіряє тільки застейджені
   зміни, а не всю історію) з конфігом `.gitleaks.toml`, якщо він є в
   репозиторії.
5. Якщо gitleaks знайшов секрет — виводиться повідомлення про помилку, звіт
   зберігається у тимчасовий JSON-файл, і **коміт відхиляється** (`exit 1`).
6. Якщо секретів немає — коміт проходить як завжди.

## Налаштування через `git config`

Усі опції мають робочі значення за замовчуванням — нічого налаштовувати не
обов'язково.

| Ключ | Значення | За замовчуванням | Опис |
|---|---|---|---|
| `hooks.gitleaks.enable` | `true` / `false` | `true` | Вмикає/вимикає перевірку повністю |
| `hooks.gitleaks.autoinstall` | `true` / `false` | `true` | Дозволяє хуку самостійно встановлювати gitleaks, якщо він відсутній |
| `hooks.gitleaks.installUrl` | URL | — (порожньо → локальний `scripts/install-gitleaks.sh`) | Звідки тягнути інсталятор через `curl \| sh` |
| `hooks.gitleaks.version` | напр. `8.21.2` | `latest` | Версія gitleaks (див. `GITLEAKS_VERSION` в install-скрипті) |

Приклади:

```bash
# тимчасово вимкнути перевірку в конкретному репозиторії
git config hooks.gitleaks.enable false

# заборонити авто-встановлення (якщо адміністратор хоче ставити gitleaks сам)
git config hooks.gitleaks.autoinstall false

# використовувати curl|sh інсталятор з конкретного URL
git config hooks.gitleaks.installUrl "https://raw.githubusercontent.com/<your-user>/<your-repo>/main/scripts/install-gitleaks.sh"
```

Разова перевірка теж можлива без хука: `gitleaks protect --staged`.

Обхід перевірки для одного коміту (стандартна поведінка git, не пов'язана з
цим хуком): `git commit --no-verify`.

## Тестування на прикладі Telegram Bot Token

Автоматичний скрипт (`test/demo.sh`) створює тимчасовий репозиторій,
встановлює хук і перевіряє обидва сценарії — коміт із секретом (має бути
відхилений) і коміт без секрету (має пройти):

```bash
sh test/demo.sh
```

### Ручна перевірка крок за кроком

```bash
mkdir /tmp/demo && cd /tmp/demo
git init
git config user.email you@example.com
git config user.name "Your Name"

# встановлюємо хук (шлях — до цього репозиторію)
sh /шлях/до/gitleaks-precommit-hook/scripts/setup-hook.sh

# "витік" Telegram bot token (це офіційний приклад-плейсхолдер із
# документації Telegram Bot API, а не реальний токен)
echo 'TELEGRAM_BOT_TOKEN = "110201543:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"' > config.py

git add config.py
git commit -m "add bot config"
```

Очікуваний результат — коміт відхилено, приблизно такий вивід:

```
→ Перевірка застейджених змін на наявність секретів (gitleaks)...

    Finding:     TELEGRAM_BOT_TOKEN = "REDACTED"
    Secret:      REDACTED
    RuleID:      telegram-bot-token
    Entropy:     X.XX
    File:        config.py
    Line:        1

════════════════════════════════════════════════════════════
  🔒 ЗНАЙДЕНО ПОТЕНЦІЙНІ СЕКРЕТИ У ЗАСТЕЙДЖЕНИХ ЗМІНАХ
════════════════════════════════════════════════════════════
  ...
✗ КОМІТ ВІДХИЛЕНО
  Причина: gitleaks виявив потенційні секрети у коміті (exit code: 1)
```

Прибираємо секрет (наприклад, читаємо токен зі змінної середовища) — коміт
проходить:

```bash
cat > config.py <<'EOF'
import os
TELEGRAM_BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
EOF
git add config.py
git commit -m "read token from env"
# ✓ Секретів не знайдено. Коміт дозволено.
```

## Що робити при хибному спрацюванні (false positive)

Додай виняток у `.gitleaks.toml` (секція `[[rules.allowlist]]` для конкретного
правила, або `[allowlist]` глобально — див.
[документацію gitleaks](https://github.com/gitleaks/gitleaks#configuration)),
або одноразово обійди перевірку через `git commit --no-verify` (з обережністю).

## Відповідність рівням завдання

| Рівень | Вимога | Де реалізовано |
|---|---|---|
| Junior (3 б.) | pre-commit hook з локально встановленим gitleaks | `hooks/pre-commit` працює з будь-яким `gitleaks` у `PATH` (Варіант 3 вище) |
| Middle (7 б.) | + автовстановлення gitleaks залежно від ОС, опція `enable` через `git config` | `scripts/install-gitleaks.sh` (визначення ОС/архітектури) + `hooks.gitleaks.enable`/`autoinstall` у `hooks/pre-commit` |
| Senior (10 б.) | + інсталяція методом `curl \| sh` | `scripts/install-gitleaks.sh` розроблений як самостійний `curl -sSfL <url> \| sh` інсталятор (як у docker/rustup); хук може підтягувати його саме так через `hooks.gitleaks.installUrl` |

## Обмеження / нотатки

- `install-gitleaks.sh` качає бінарник з GitHub Releases проєкту
  `gitleaks/gitleaks`, тому для першого встановлення потрібен інтернет.
  Наступні коміти вже не залежать від мережі.
- Правило для Telegram Bot Token додане явно в `.gitleaks.toml` (окрім
  стандартного набору правил gitleaks), щоб гарантовано ловити формат
  `<bot_id>:<35 символів>` незалежно від версії gitleaks.
- Скрипти написані на bash (`hooks/pre-commit`, `test/demo.sh`) та POSIX
  `sh` (`scripts/install-gitleaks.sh`, `scripts/setup-hook.sh`) для
  максимальної сумісності.

## Ліцензія

MIT — див. [LICENSE](LICENSE).
