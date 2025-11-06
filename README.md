# QUICK swap Ubuntu 22.04

A small utility for quickly creating, deleting, and checking a swap file on a Linux server. Originally written and tested for Ubuntu 22.04, it can also work on other modern Linux distributions (see the "Supported OS" section).

Key Features

Create a swap file (with interactive size prompt or with the --size option)
Delete a swap file (with confirmation or with --force)
Display swap status (--action status)
Safe dry-run (-n / --dry-run) — shows which commands will be executed without changing the system
Basic localization support: --lang ru|en (files in i18n/)
Files in the repository

swap_mini.sh — main script. Run as root (the script checks the $EUID and requires sudo to run).
i18n/ru.sh, i18n/en.sh — simple language files for messages.
Supported OSes

- Tested: Ubuntu 22.04 (recommended)
- Expected compatibility: Debian 11/12, modern CentOS/RHEL 8+, Rocky/AlmaLinux — these have both coreutils/util-linux and systemd in typical installs.
- Systemd note: the `--systemd` option (create a systemd .swap unit) requires systemd on the host. Typical systemd-enabled releases include Ubuntu 16.04+, Debian 8+, CentOS/RHEL 7+, Rocky/AlmaLinux 8+.
- Not supported: macOS, FreeBSD (the `mkswap`, `swapon`, and `/proc/meminfo` commands are Linux-specific)
Requirements (server-side)

Bash
coreutils (df, grep, awk, sed)
util-linux (mkswap, swapon, swapoff)
Root privileges for system-modifying actions
Dangers and Cautions

The script edits /etc/fstab. In production mode, it creates a backup copy of /etc/fstab.bak before writing. However, test in an isolated VM (multipass/LXC/VM) before going into production. dd writes zeros and can take up time and disk space. Do not run in production without checking for free space.
Usage Examples

Dry-run: Preview what will be done (recommended before running)
```bash
sudo bash swap_mini.sh --action create --size 128 --path /swapfile --lang ru --dry-run
sudo bash swap_mini.sh -n --action create --size 128
```
Create a 128 MB swap file (real)
```bash
sudo bash swap_mini.sh --action create --size 128 --path /swapfile
# or create using a systemd unit (if your distro uses systemd):
sudo bash swap_mini.sh --action create --size 128 --path /swapfile --systemd
```
Delete the swap file (with confirmation). For automatic deletion, use --force. sudo 
```bash
bash swap_mini.sh --action remove --path /swapfile
sudo bash swap_mini.sh --action remove --path /swapfile --force
```
View swap status
```bash
sudo bash swap_mini.sh --action status
```
Parameters and options

-n, --dry-run — do not make changes, only show commands and checks.
--action — one of create|remove|status (default: create).
--size — size in MB (can be passed via an option or interactively when creating).
--path — path to the swap file (default: /swapfile).
-f, --force — skip confirmation when removing.
--lang — message language (ru or en).
Post-execution checks

Check that swap is enabled:
```bash
swapon -s
```
Make sure /etc/fstab contains an entry:
```bash
grep '/swapfile' /etc/fstab
```
Testing in multipass (recommended safe scenario)

Create an Ubuntu 22.04 VM:
```bash
multipass launch --name swap-test ubuntu:22.04
multipass shell swap-test
```
Copy the script inside the VM and run dry-run:
```bash
sudo bash swap_mini.sh --action create --size 128 --path /swapfile -n
```
If dry-run is successful, run the real run (in the VM):
```bash
sudo bash swap_mini.sh --action create --size 128 --path /swapfile
swapon -s
grep /swapfile /etc/fstab
```
Rollback and remove

Remove via script: sudo bash swap_mini.sh --action remove --path /swapfile.
The script attempts to save /etc/fstab.bak before modifying it—check the backup if necessary.
Localization

Language files are located in i18n/. To add a new language, create a file i18n/<code>.sh with a set of variable messages (for example, ru.sh and en.sh).

Author and License

The script and repository are MIT-compatible; see the LICENSE file.

Небольшая утилита для быстрого создания/удаления/проверки swap-файла на Linux-сервере. Изначально написана и протестирована для Ubuntu 22.04, но может работать и на других современных Linux-дистрибутивах (см. раздел "Поддерживаемые ОС").

Основные возможности
- создать swap-файл (с интерактивным запросом размера или с опцией `--size`)
- удалить swap-файл (с подтверждением или с `--force`)
- вывести статус swap (`--action status`)
- безопасный dry-run (`-n` / `--dry-run`) — покажет, какие команды будут выполнены, не изменяя систему
- базовая поддержка локализации: `--lang ru|en` (файлы в `i18n/`)

Файлы в репозитории
- `swap_mini.sh` — основной скрипт. Запуск под root (скрипт проверяет `$EUID` и просит запуск через `sudo`).
- `i18n/ru.sh`, `i18n/en.sh` — простые языковые файлы для сообщений.

Поддерживаемые ОС
- Тестировано: Ubuntu 22.04 (рекомендуется)
- Ожидаемо совместимо: Debian 11/12, современные CentOS/RHEL 8+, Rocky/AlmaLinux (при наличии утилит coreutils и util-linux)
- Не поддерживается: macOS, FreeBSD (команды `mkswap`, `swapon`, `/proc/meminfo` — Linux-специфичны)

Требования (на стороне сервера)
- Bash
- coreutils (df, grep, awk, sed)
- util-linux (mkswap, swapon, swapoff)
- права root для выполнения действий, меняющих систему

Опасности и предостережения
- Скрипт редактирует `/etc/fstab`. В реальном режиме он создаёт резервную копию `/etc/fstab.bak` перед записью. Тем не менее тестируйте в изолированной VM (multipass/LXC/VM) перед продом.
- `dd` записывает нули и может занять время и диск. Не запускайте в продакшн без проверки свободного места.

Примеры использования

1) Dry-run: посмотреть, что будет сделано (рекомендуется перед реальным запуском)

```bash
sudo bash swap_mini.sh --action create --size 128 --path /swapfile --lang ru --dry-run
sudo bash swap_mini.sh -n --action create --size 128
```

2) Создать swap-файл 128 МБ (реально)

```bash
sudo bash swap_mini.sh --action create --size 128 --path /swapfile
```

3) Удалить swap-файл (с подтверждением). Для автоматического удаления используйте `--force`.

```bash
sudo bash swap_mini.sh --action remove --path /swapfile
sudo bash swap_mini.sh --action remove --path /swapfile --force
```

4) Посмотреть статус swap

```bash
sudo bash swap_mini.sh --action status
```

Параметры и опции
- `-n`, `--dry-run` — не вносить изменений, только показать команды и проверки.
- `--action` — одно из `create|remove|status` (по умолчанию `create`).
- `--size` — размер в МБ (при `create` можно передать через опцию или в интерактивном режиме).
- `--path` — путь к swap-файлу (по умолчанию `/swapfile`).
- `-f`, `--force` — при `remove` пропускать подтверждение.
- `--lang` — язык сообщений (`ru` или `en`).

Проверки после выполнения
- Проверьте, что swap включён:

```bash
swapon -s
```

- Убедитесь, что `/etc/fstab` содержит запись:

```bash
grep '/swapfile' /etc/fstab
```

Тестирование в multipass (рекомендуемый безопасный сценарий)

1) Создайте VM Ubuntu 22.04:

```bash
multipass launch --name swap-test ubuntu:22.04
multipass shell swap-test
```

2) Внутри VM скопируйте скрипт и выполните dry-run:

```bash
sudo bash swap_mini.sh --action create --size 128 --path /swapfile -n
```

3) Если dry-run в порядке — выполните реальный запуск (в VM):

```bash
sudo bash swap_mini.sh --action create --size 128 --path /swapfile
swapon -s
grep /swapfile /etc/fstab
```

Откат и удаление
- Удаление через скрипт: `sudo bash swap_mini.sh --action remove --path /swapfile`.
- Скрипт пытается сохранить `/etc/fstab.bak` перед изменением — проверьте бэкап при необходимости.

Локализация
- Языковые файлы находятся в `i18n/`. Добавление нового языка — создать файл `i18n/<код>.sh` с набором переменных сообщений (пример `ru.sh` и `en.sh`).


Автор и лицензия
- Скрипт и репозиторий — MIT-совместимый; см. файл `LICENSE`.