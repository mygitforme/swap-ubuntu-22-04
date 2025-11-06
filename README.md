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
```markdown
# swap-ubuntu-22-04 — быстрый SWAP-менеджер для серверного Linux

Небольшая утилита для быстрого создания, удаления и проверки swap-файла на серверных Linux-дистрибутивах. Изначально разработана для Ubuntu 22.04, но совместима с большинством современных дистрибутивов с coreutils/util-linux и (опционально) systemd.

Кратко
- Подход: безопасный однофайловый bash-скрипт, запускаемый от root (скрипт проверяет `$EUID`).
- Цель: дать простой, проверяемый workflow для создания `/swapfile` или systemd `.swap` unit.

Ключевые возможности
- create/remove/status — основные действия (`--action create|remove|status`).
- dry-run: `-n` / `--dry-run` — симулирует действия, не влияет на систему.
- systemd: опция `--systemd` позволяет создать/включить `.swap` unit вместо записи в `/etc/fstab`.
- i18n: поддержка языков через `i18n/*.sh` и автоматическое обнаружение/выбор языка (`--lang`, `SWAP_LANG`).
- Suggest size: `--suggest-size` — подсказка рекомендованного размера swap по объёму RAM.

Файлы в репозитории
- `swap_mini.sh` — основной скрипт (используйте `sudo bash swap_mini.sh ...`).
- `i18n/ru.sh`, `i18n/en.sh` — примеры переводов сообщений.
- `LICENSE`, `README.md` — лицензия и документация.

Поддерживаемые ОС
- Рекомендуется: Ubuntu 22.04 (тестирование). Проект целится на серверные Linux-дистрибутивы: Debian, Ubuntu, CentOS/RHEL, Rocky/AlmaLinux и т.д.
- Опция `--systemd` требует systemd на хосте.
- Не поддерживается: macOS, BSD-подобные системы (утилиты `mkswap`, `swapon`, `/proc/meminfo` — Linux-специфичны).

Требования
- Bash
- coreutils: `df`, `grep`, `awk`, `sed`
- util-linux: `mkswap`, `swapon`, `swapoff`
- права root для действий, изменяющих систему

Безопасность и предостережения
- Скрипт модифицирует системное состояние и может править `/etc/fstab`. Всегда выполняйте `-n/--dry-run` сначала.
- Скрипт делает резервную копию `/etc/fstab` перед записью (обычно `/etc/fstab.bak`).
- `dd` выделяет место и пишет нули — проверьте свободное место и влияние на систему перед выполнением.

Использование — примеры

1) Dry-run (рекомендуется перед реальным запуском)
```bash
sudo bash swap_mini.sh -n --action create --size 512 --path /swapfile --lang ru
sudo bash swap_mini.sh --dry-run --action create --suggest-size
```

2) Создать swap-файл 1 GB
```bash
sudo bash swap_mini.sh --action create --size 1024 --path /swapfile
```

3) Создать systemd `.swap` unit вместо /etc/fstab
```bash
sudo bash swap_mini.sh --action create --size 1024 --path /swapfile --systemd --unit-name my-swap
```

4) Удалить swap (с подтверждением) или автоматически
```bash
sudo bash swap_mini.sh --action remove --path /swapfile
sudo bash swap_mini.sh --action remove --path /swapfile --force
```

5) Показать статус swap
```bash
sudo bash swap_mini.sh --action status
```

Параметры и опции (основные)
- `-n`, `--dry-run` — симулировать действия, не вносить изменений.
- `--action` — `create|remove|status` (по умолчанию `create`).
- `--size` — размер в МБ (при `create`).
- `--path` — путь к swap-файлу (по умолчанию `/swapfile`).
- `-f`, `--force` — при `remove` пропускать подтверждение.
- `--systemd` — использовать systemd unit вместо `/etc/fstab`.
- `--unit-name` — имя для unit (если не задано, используется basename пути).
- `--lang` или `SWAP_LANG` — язык сообщений; скрипт автоматически обнаруживает `i18n/*.sh`.
- `--suggest-size` — вывести рекомендуемый размер swap по объёму RAM.

Проверки после выполнения
- `swapon -s` — список активных swap-ресурсов.
- `grep '/swapfile' /etc/fstab` — проверка записи (если не используется systemd).

Тестирование (рекомендованный безопасный сценарий)

Тестируйте в изолированной виртуальной машине или контейнере (LXC, VirtualBox, cloud VM и т.п.). Общие шаги:

1. Создайте изолированную среду и подключитесь к ней.
2. Скопируйте `swap_mini.sh` в среду и выполните dry-run для проверки логики:

```bash
sudo bash swap_mini.sh --action create --size 128 --path /swapfile -n
```

3. Если dry-run прошёл успешно — выполните реальный запуск и проверьте результаты:

```bash
sudo bash swap_mini.sh --action create --size 128 --path /swapfile
swapon -s
grep /swapfile /etc/fstab
# или при использовании systemd: systemctl status <unit-name>
```

Локализация
- Языковые файлы находятся в `i18n/`. Для добавления нового языка создайте `i18n/<code>.sh` с набором MSG_* переменных, аналогичных `ru.sh` и `en.sh`.
- Скрипт поддерживает автоматическое обнаружение доступных языков и выбор через `--lang` или переменную окружения `SWAP_LANG`.

Автор и лицензия
- MIT-совместимая лицензия — смотрите файл `LICENSE`.

```