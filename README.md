# QUICK swap Ubuntu 22.04

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

Дальнейшие улучшения (идеи)
- Полная локализация всех сообщений через языковые ключи.
- Имитация dry-run с созданием временного файла (полезно для CI).
- Небольшие автоматические тесты (проверка вывода dry-run, аргументов).
- Поддержка systemd swap units (как альтернатива swapfile + fstab).

Если хотите, я могу добавить пример вывода dry-run в README, реализовать имитацию dry-run для CI или полностью локализовать оставшиеся сообщения.

Автор и лицензия
- Скрипт и репозиторий — MIT-совместимый; см. файл `LICENSE`.
