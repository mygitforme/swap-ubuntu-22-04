#!/usr/bin/env bash
# swap_mini.sh - small utility to create/remove/status swapfile

b='\033[1m'
l='\033[4m'
y='\033[1;33m'
g='\033[0;32m'
r='\033[0;31m'
e='\033[0m'

set -u

# Defaults
DRY_RUN=0
SWAP_PATH="/swapfile"
SWAP_SIZE_ARG=""
ACTION="create" # create|remove|status
FORCE=0
LANG=""
LANG_SET=0
SYSTEMD=0
SUGGEST_SIZE=0
MIN_SWAP_MB=128

usage(){
  cat <<EOF
Usage: sudo bash $0 [options]
Options:
  -n, --dry-run         Show actions without changing system
  --action create|remove|status   Action to perform (default: create)
  --size <MB>           Swap size in MB (for create)
  --path <path>         Path to swap file (default: /swapfile)
  -f, --force           Force destructive actions (remove without prompt)
  --lang ru|en          Language for messages (ru default)
  --systemd             Use systemd .swap unit instead of /etc/fstab
  --suggest-size        Print a recommended swap size based on RAM and exit
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1; shift ;;
    --suggest-size) SUGGEST_SIZE=1; shift ;;
    --size) SWAP_SIZE_ARG="$2"; shift 2 ;;
    --path) SWAP_PATH="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    -f|--force) FORCE=1; shift ;;
  --lang) LANG="$2"; LANG_SET=1; shift 2 ;;
    --systemd) SYSTEMD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "${ERROR_ARG}: $1"; usage; exit 1 ;;
  esac
done

# If language was not provided explicitly, discover available languages and prompt the user (interactive)
I18N_DIR="$(dirname "$0")/i18n"
if [ "${LANG_SET}" -eq 0 ]; then
  avail=()
  if [ -d "${I18N_DIR}" ]; then
    for f in "${I18N_DIR}"/*.sh; do
      [ -e "$f" ] || continue
      avail+=("$(basename "$f" .sh)")
    done
  fi
  if [ ${#avail[@]} -eq 0 ]; then
    LANG="ru"
  elif [ ${#avail[@]} -eq 1 ]; then
    LANG="${avail[0]}"
  else
    # interactive selection when possible
    if [ -t 0 ]; then
      echo "Available languages:"
      i=1
      for name in "${avail[@]}"; do
        echo "  $i) $name"
        i=$((i+1))
      done
      read -p "Choose language [1-${#avail[@]}] (default: 1): " choice
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#avail[@]} ]; then
        LANG="${avail[$((choice-1))]}"
      else
        LANG="${avail[0]}"
      fi
    else
      # non-interactive: try env LANG, else pick first
      if [ -n "${LANG}" ]; then
        :
      else
        LANG="${avail[0]}"
      fi
    fi
  fi
fi

# load i18n
I18N_FILE="${I18N_DIR}/${LANG}.sh"
if [ -f "${I18N_FILE}" ]; then
  # shellcheck source=/dev/null
  . "${I18N_FILE}"
else
  . "${I18N_DIR}/ru.sh"
fi

run_cmd() {
  if [ "${DRY_RUN}" -eq 1 ]; then
    echo -e "${y}[DRY-RUN] $*${e}"
    return 0
  else
    eval "$@"
    return $?
  fi
}

# If user requested suggestion only, compute RAM and print recommendation (allow non-root)
if [ "$SUGGEST_SIZE" -eq 1 ]; then
  if [ -r /proc/meminfo ]; then
    ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    if [[ "$ram_kb" =~ ^[0-9]+$ ]]; then
      ram_mb=$((ram_kb/1024))
      if [ $ram_mb -le 2048 ]; then
        suggested_mb=$ram_mb
        note="RAM ≤ 2 GB — рекомендуем swap ≈ объёму RAM"
      else
        suggested_mb=2048
        note="RAM > 2 GB — рекомендуем 1–2 GB; по умолчанию предлагается 2 GB"
      fi
      echo -e "Рекомендованный размер swap: ${suggested_mb} MB\nПримечание: ${note} (RAM=${ram_mb} MB)"
      exit 0
    else
      echo "Не удалось прочитать MemTotal из /proc/meminfo" >&2
      exit 1
    fi
  else
    echo "/proc/meminfo не доступен" >&2
    exit 1
  fi
fi

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${r}${MSG_ROOT_REQUIRED} ${l}root${e}. ${MSG_PLEASE_SUDO:-Запустите через: sudo bash $0}" 
    exit 1
  fi
}

detect_existing_swap() {
  EXISTING_SWAPS=()
  if [ -r /proc/swaps ]; then
    while read -r name type size used priority; do
      if [ "$name" != "Filename" ] && [ -n "$name" ]; then
        EXISTING_SWAPS+=("${name}:${size}")
      fi
    done < /proc/swaps
  else
    # fallback to swapon -s parsing
    while read -r line; do
      [ -z "$line" ] && continue
      if [[ "$line" == Filename* ]]; then
        continue
      fi
      name=$(echo "$line" | awk '{print $1}')
      size_kb=$(echo "$line" | awk '{print $3}')
      [ -n "$name" ] && EXISTING_SWAPS+=("${name}:${size_kb}")
    done < <(swapon -s 2>/dev/null)
  fi

  if [ ${#EXISTING_SWAPS[@]} -gt 0 ]; then
    echo -e "${MSG_EXISTING_SWAP}:"
    for s in "${EXISTING_SWAPS[@]}"; do
      path=${s%%:*}
      size_kb=${s##*:}
      size_mb=$((size_kb/1024))
      echo -e " - ${path} (${size_mb} MB)"
    done
    return 0
  fi
  return 1
}

remove_existing_swaps() {
  for s in "${EXISTING_SWAPS[@]}"; do
    path=${s%%:*}
    echo -e "Removing swap: ${path}"
    run_cmd "swapoff ${path}"
    if [ "${DRY_RUN}" -eq 1 ]; then
      echo -e "${y}[DRY-RUN] sed -i '/${path//\//\/}/d' /etc/fstab${e}"
    else
      sed -i.bak "/${path//\//\/}/d" /etc/fstab || true
    fi
    if [ -f "${path}" ] && [ "${DRY_RUN}" -ne 1 ]; then
      rm -f "${path}" || true
    fi
  done
  echo -e "${MSG_REMOVED}"
}

create_systemd_unit() {
  unit_name=$(basename "${SWAP_PATH}")
  unit_file="/etc/systemd/system/${unit_name}.swap"
  echo -e "${MSG_UNIT_NAME}: ${unit_name}"
  if [ "${DRY_RUN}" -eq 1 ]; then
    echo -e "${y}[DRY-RUN] create unit ${unit_file} pointing to ${SWAP_PATH}${e}"
    return 0
  fi
  cat > "${unit_file}" <<EOF
[Unit]
Description=Swap file ${SWAP_PATH}

[Swap]
What=${SWAP_PATH}
Priority=-2

[Install]
WantedBy=multi-user.target
EOF
  run_cmd "systemctl daemon-reload"
  run_cmd "systemctl enable --now ${unit_name}.swap"
  echo -e "${MSG_UNIT_CREATED}: ${unit_file}"
  echo -e "${MSG_UNIT_ENABLED}"
}

remove_systemd_unit() {
  unit_name=$(basename "${SWAP_PATH}")
  unit_file="/etc/systemd/system/${unit_name}.swap"
  run_cmd "systemctl disable --now ${unit_name}.swap || true"
  if [ "${DRY_RUN}" -eq 1 ]; then
    echo -e "${y}[DRY-RUN] rm -f ${unit_file}${e}"
  else
    rm -f "${unit_file}" || true
    run_cmd "systemctl daemon-reload"
  fi
  echo -e "${MSG_UNIT_REMOVED}"
}

perform_create() {
  detect_existing_swap
  if [ $? -eq 0 ]; then
    echo -e "${MSG_PROMPT_EXISTING_ACTION}"
    read -p "[r/k/c]: " choice
    case "$choice" in
      r|R)
        remove_existing_swaps
        ;;
      k|K)
        echo "Keeping existing swaps and creating additional one"
        ;;
      *)
        echo -e "${MSG_CANCELLED}"
        exit 0
        ;;
    esac
  fi

  # size
  if [ -n "${SWAP_SIZE_ARG}" ]; then
    swap_size_mb="${SWAP_SIZE_ARG}"
  else
    read -p "${MSG_ENTER_SIZE} " swap_size_mb
  fi
  if [[ ! ${swap_size_mb} =~ ^[0-9]+$ ]]; then
    echo -e "${r}${l}${MSG_ERROR_ONLY_DIGITS}${e}"
    exit 1
  fi

  # normalize (remove leading zeros)
  swap_size_mb=$(echo "${swap_size_mb}" | sed 's/^0*//')
  if [ -z "${swap_size_mb}" ]; then
    echo -e "${r}${l}${MSG_ERROR_ONLY_DIGITS}${e}"
    exit 1
  fi

  # minimal size check
  if [ ${swap_size_mb} -lt ${MIN_SWAP_MB} ]; then
    echo -e "${r}${l}Минимальный допустимый размер swap: ${MIN_SWAP_MB} MB${e}"
    exit 1
  fi

  free_space_mb=$(df -BM --output=avail / | sed '1d;s/[^0-9]*//g')
  if [ -n "${free_space_mb}" ] && [ ${free_space_mb} -lt ${swap_size_mb} ]; then
    echo -e "${r}${l}${MSG_ERROR_NOT_ENOUGH_SPACE}${e}"
    exit 1
  fi

  # warn if requested size is large relative to free disk (e.g. >50% of free space)
  if [ -n "${free_space_mb}" ] && [ ${swap_size_mb} -gt $((free_space_mb/2)) ]; then
    echo -e "${y}Внимание: запрошенный размер ${swap_size_mb} MB составляет >50% доступного места (${free_space_mb} MB).${e}"
    if [ "${DRY_RUN}" -ne 1 ] && [ "${FORCE}" -ne 1 ]; then
      read -p "Продолжить? [y/N] " ok
      case "${ok}" in
        [Yy]*) ;;
        *) echo "Отменено"; exit 1 ;;
      esac
    fi
  fi

  run_cmd "dd if=/dev/zero of=${SWAP_PATH} bs=1M count=${swap_size_mb}"
  if [ ! -f "${SWAP_PATH}" ] && [ "${DRY_RUN}" -ne 1 ]; then
    echo -e "${r}${l}${MSG_ERROR_CREATE_FAILED}${e}"
    exit 1
  fi
  run_cmd "chmod 600 ${SWAP_PATH}"
  run_cmd "mkswap ${SWAP_PATH}"
  if [ "${SYSTEMD}" -eq 1 ]; then
    create_systemd_unit
  else
    if [ "${DRY_RUN}" -eq 1 ]; then
      echo -e "${y}[DRY-RUN] echo '${SWAP_PATH} none swap sw 0 0' >> /etc/fstab${e}"
    else
      cp /etc/fstab /etc/fstab.bak || true
      grep -qF "${SWAP_PATH} none swap sw 0 0" /etc/fstab || echo "${SWAP_PATH} none swap sw 0 0" >> /etc/fstab
    fi
  fi
  run_cmd "swapon ${SWAP_PATH}"
  if [ "${DRY_RUN}" -eq 1 ]; then
    echo -e "${y}[DRY-RUN] Проверка: swapon -s | grep ${SWAP_PATH}${e}"
  else
    if [ -z "$(swapon -s | grep ${SWAP_PATH})" ]; then
      echo -e "${r}${l}${MSG_ERROR_ENABLE_FAILED}${e}"
      exit 1
    fi
  fi
  echo -e "${g}${MSG_SUCCESS_CREATED}${e}"
}

perform_remove() {
  detect_existing_swap || true
  if [ ${#EXISTING_SWAPS[@]} -gt 0 ]; then
    echo -e "${MSG_SWAP_DETAILS}:"
    for s in "${EXISTING_SWAPS[@]}"; do
      path=${s%%:*}
      echo " - ${path}"
    done
  fi

  if [ "${FORCE}" -ne 1 ]; then
    read -p "Confirm removal of ${SWAP_PATH}? [y/N] " yn
    case "$yn" in
      [Yy]*) ;;
      *) echo "${MSG_CANCELLED}"; exit 0;;
    esac
  fi

  if [ "${SYSTEMD}" -eq 1 ]; then
    remove_systemd_unit
  else
    run_cmd "swapoff ${SWAP_PATH}"
    if [ "${DRY_RUN}" -eq 1 ]; then
      echo -e "${y}[DRY-RUN] sed -i '/${SWAP_PATH//\//\\/}/d' /etc/fstab${e}"
    else
      sed -i.bak "/${SWAP_PATH//\//\\/}/d" /etc/fstab || true
    fi
    if [ -f "${SWAP_PATH}" ] && [ "${DRY_RUN}" -ne 1 ]; then
      rm -f "${SWAP_PATH}" || true
    fi
  fi
  echo -e "${MSG_REMOVED}"
}

perform_status() {
  echo -e "${MSG_SWAP_DETAILS}:"
  swapon -s
  if [ "${SYSTEMD}" -eq 1 ]; then
    unit_name=$(basename "${SWAP_PATH}")
    echo -e "${MSG_UNIT_NAME}: ${unit_name}.swap"
    systemctl status ${unit_name}.swap --no-pager || true
  fi
}

# main
ensure_root
case "${ACTION}" in
  create) perform_create ;;
  remove) perform_remove ;;
  status) perform_status ;;
  *) echo "Unknown action: ${ACTION}"; usage; exit 1 ;;
esac

suggest_size() {
  # read RAM in kB from /proc/meminfo
  if [ -r /proc/meminfo ]; then
    ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  else
    echo "Cannot read /proc/meminfo to detect RAM" >&2
    return 1
  fi
  if [[ ! "$ram_kb" =~ ^[0-9]+$ ]]; then
    echo "Unexpected MemTotal value: $ram_kb" >&2
    return 1
  fi
  ram_mb=$((ram_kb/1024))
  if [ $ram_mb -le 2048 ]; then
    suggested_mb=$ram_mb
    note="RAM ≤ 2 GB — рекомендуем swap ≈ объёму RAM"
  else
    suggested_mb=2048
    note="RAM > 2 GB — рекомендуем 1–2 GB; по умолчанию предлагается 2 GB"
  fi
  echo -e "Рекомендованный размер swap: ${suggested_mb} MB\nПримечание: ${note} (RAM=${ram_mb} MB)"
  return 0
}

# If user requested suggestion only, print and exit
if [ "$SUGGEST_SIZE" -eq 1 ]; then
  suggest_size
  exit 0
fi
  *) echo "Unknown action: ${ACTION}"; usage; exit 1 ;;
esac

#!/bin/bash
b='\033[1m'
l='\033[4m'
y='\033[1;33m'
g='\033[0;32m'
r='\033[0;31m'
e='\033[0m'

# Парсинг параметров: поддерживаем -n | --dry-run
DRY_RUN=0
while [[ $# -gt 0 ]]; do
   case "$1" in
      -n|--dry-run)
         DRY_RUN=1
         shift
         ;;
      *)
         break
# Парсинг параметров: поддерживаем -n|--dry-run, --size, --path, --action, --force, --lang
   esac
done

# Утилита-обёртка для выполнения команд — в dry-run печатает, иначе выполняет
run_cmd() {
   if [ "${DRY_RUN}" -eq 1 ]; then
      echo -e "${y}[DRY-RUN] $*${e}"
      return 0
   else
      eval "$@"
      return $?
   fi

# load i18n
I18N_FILE="$(dirname "$0")/i18n/${LANG}.sh"
if [ -f "${I18N_FILE}" ]; then
   # shellcheck source=/dev/null
   . "${I18N_FILE}"
else
   # fallback to ru
   . "$(dirname "$0")/i18n/ru.sh"
fi

}

# Проверяем, что скрипт запущен от имени root (требование сохраняем)
if [[ $EUID -ne 0 ]]; then
    echo -e "${r}Этот скрипт должен быть запущен от имени ${l}root${e}. Запустите через: ${b}sudo bash $0${e}" 
    exit 1
fi

# Определяем размер свободного места на диске в переменную free_space
free_space=$(df -BG --output=avail / | sed '1d;s/[^0-9.]*//g')
swap_size=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
echo -e "размер свободного места на диске ${g}$free_space${e}"
echo -e "размер swap: ${g}$swap_size kB${e}"

# Проверяем, что переменная free_space определена
if [ -z "$free_space" ]; then
  echo -e "${r}${l}Ошибка${e}: переменная ${b}free_space${e} не определена${e}"
  exit 1
fi

# Проверяем, что есть достаточно свободного места на диске и swap
# Проверяем, что есть достаточно свободного места на диске и swap
if [ $free_space -lt $((swap_size/1024)) ]; then
   echo -e "${r}${l}Ошибка${e}: на диске недостаточно свободного места для swap${e}"
   exit 1
fi
# Выключаем текущий swap (в dry-run напечатаем команду)
run_cmd "swapoff -a"
# Запрашиваем у пользователя размер swap-файла в МБ и вносим в переменную swap_size
# Запрашиваем у пользователя размер swap-файла в МБ и вносим в переменную swap_size
read -p "Введите размер swap-файла в МБ " swap_size

# Проверяем, что переменная swap_size содержит только цифры

# simple action dispatcher
perform_create() {
   # determine requested size: priority CLI arg > interactive
   if [ -n "${SWAP_SIZE_ARG}" ]; then
      swap_size_mb="${SWAP_SIZE_ARG}"
   else
      read -p "${MSG_ENTER_SIZE} " swap_size_mb
   fi
   if [[ ! ${swap_size_mb} =~ ^[0-9]+$ ]]; then
      echo -e "${r}${l}${MSG_ERROR_ONLY_DIGITS}${e}"
      exit 1
   fi
   # check free space
   if [ ${free_space} -lt $((swap_size_mb)) ]; then
      echo -e "${r}${l}${MSG_ERROR_NOT_ENOUGH_SPACE}${e}"
      exit 1
   fi

   run_cmd "dd if=/dev/zero of=${SWAP_PATH} bs=1M count=${swap_size_mb}"
   if [ ! -f "${SWAP_PATH}" ] && [ "${DRY_RUN}" -ne 1 ]; then
      echo -e "${r}${l}${MSG_ERROR_CREATE_FAILED}${e}"
      exit 1
   fi
   run_cmd "chmod 600 ${SWAP_PATH}"
   run_cmd "mkswap ${SWAP_PATH}"
   if [ "${DRY_RUN}" -eq 1 ]; then
      echo -e "${y}[DRY-RUN] echo '${SWAP_PATH} none swap sw 0 0' >> /etc/fstab${e}"
   else
      cp /etc/fstab /etc/fstab.bak
      grep -qF "${SWAP_PATH} none swap sw 0 0" /etc/fstab || echo "${SWAP_PATH} none swap sw 0 0" >> /etc/fstab
   fi
   run_cmd "swapon ${SWAP_PATH}"
   if [ "${DRY_RUN}" -eq 1 ]; then
      echo -e "${y}[DRY-RUN] Проверка: swapon -s | grep ${SWAP_PATH}${e}"
   else
      if [ -z "$(swapon -s | grep ${SWAP_PATH})" ]; then
         echo -e "${r}${l}${MSG_ERROR_ENABLE_FAILED}${e}"
         exit 1
      fi
   fi
   echo -e "${g}${MSG_SUCCESS_CREATED}${e}"
}

perform_remove() {
   if [ "${FORCE}" -ne 1 ]; then
      read -p "Confirm removal of ${SWAP_PATH}? [y/N] " yn
      case "$yn" in
         [Yy]*) ;;
         *) echo "Aborted"; exit 0;;
      esac
   fi
   run_cmd "swapoff ${SWAP_PATH}"
   if [ "${DRY_RUN}" -eq 1 ]; then
      echo -e "${y}[DRY-RUN] sed -i '/${SWAP_PATH//\//\\/}/d' /etc/fstab${e}"
   else
      sed -i.bak "/${SWAP_PATH//\//\\/}/d" /etc/fstab && echo "/etc/fstab backed up to /etc/fstab.bak"
   fi
   if [ -f "${SWAP_PATH}" ] && [ "${DRY_RUN}" -ne 1 ]; then
      rm -f "${SWAP_PATH}"
   fi
   echo "Removed ${SWAP_PATH}"
}

perform_status() {
   echo -e "Current swap entries:"
   swapon -s
}

case "${ACTION}" in
   create) perform_create ;;
   remove) perform_remove ;;
   status) perform_status ;;
   *) echo "Unknown action: ${ACTION}"; exit 1 ;;
esac

if [[ ! $swap_size =~ ^[0-9]+$ ]]; then
   echo -e "${r}${l}Ошибка${e}: переменная swap_size должна содержать ${l}только цифры${e}${e}"
   exit 1
fi


# Создаем swap-файл (через run_cmd — в dry-run будет только напечатано)
run_cmd "dd if=/dev/zero of=/swapfile bs=1M count=$swap_size"

# Проверяем, что swap-файл создан успешно
if [ ! -f "/swapfile" ]; then
   echo -e "${r}${l}Ошибка${e}: не удалось создать swap-файл${e}"
   exit 1
fi


# Устанавливаем права доступа и монтируем swap (через run_cmd чтобы dry-run был безопасен)
run_cmd "chmod 600 /swapfile"
run_cmd "mkswap /swapfile"

# Добавляем запись в fstab безопасно: проверяем дубликат и делаем бэкап в реальном режиме
if [ "${DRY_RUN}" -eq 1 ]; then
   echo -e "${y}[DRY-RUN] echo '/swapfile none swap sw 0 0' >> /etc/fstab${e}"
else
   cp /etc/fstab /etc/fstab.bak
   grep -qF '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Включаем swap-файл
run_cmd "swapon /swapfile"

# Проверяем, что swap-файл включен успешно (в dry-run - просто выводим ожидаемый результат)
if [ "${DRY_RUN}" -eq 1 ]; then
   echo -e "${y}[DRY-RUN] Проверка: swapon -s | grep /swapfile${e}"
else
   if [ -z "$(swapon -s | grep /swapfile)" ]; then
      echo -e "${r}${l}Ошибка${e}: не удалось включить swap-файл${e}"
      exit 1
   fi
fi

# Выводим сообщение об успешном завершении операции с подробностями
echo -e "${g}Swap-файл размером ${b}$swap_size МБ${e} создан успешно и включен в систему. Для проверки можно выполнить команду '${b}swapon -s${e}'.${e}"
