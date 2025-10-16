#!/bin/bash

show_help() {
  cat <<EOF
Использование: $(basename "$0") <папка_логов> [порог_в_процентах]

Скрипт проверяет заполнение указанной папки логов относительно общего объёма файловой системы.
Если использование превышает заданный порог, старые файлы архивируются и удаляются.

Аргументы:
  <папка_логов>           Путь к директории с логами (обязательный аргумент)
  [порог_в_процентах]     Порог заполнения в процентах (по умолчанию 70)

Примеры:
  $(basename "$0") /var/log
  $(basename "$0") /var/log 80

Опции:
  -h, --help              Показать эту справку и выйти
EOF
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
  exit 0
fi

LOG_DIR="$1"
THRESHOLD=${2:-70}

if [ -z "$LOG_DIR" ] || [ ! -d "$LOG_DIR" ]; then
  echo "Ошибка: укажите корректный путь к папке в аргументе 1"
  echo "Используйте --help для справки."
  exit 1
fi

CURRENT_SIZE_MB=$(du -sm "$LOG_DIR" | cut -f1)
TOTAL_SIZE_MB=$(df -m "$LOG_DIR" | tail -1 | awk '{print $2}')
PERCENT_USED=$(( CURRENT_SIZE_MB * 100 / TOTAL_SIZE_MB ))

echo "Заполнение папки $LOG_DIR: $PERCENT_USED% (порог $THRESHOLD%)"

if (( PERCENT_USED > THRESHOLD )); then
  echo "Превышен порог, архивируем и удаляем старые файлы..."

  TARGET_SIZE_MB=$(( CURRENT_SIZE_MB - TOTAL_SIZE_MB * THRESHOLD / 100 ))

  cd "$LOG_DIR" || exit 1

  FILES_TO_ARCHIVE=()
  ACCUM_SIZE=0

  while IFS= read -r -d '' file; do
    if [ -f "$file" ]; then
      FILE_SIZE_MB=$(du -m "$file" | cut -f1)
      FILES_TO_ARCHIVE+=("$file")
      ACCUM_SIZE=$(( ACCUM_SIZE + FILE_SIZE_MB ))
      if (( ACCUM_SIZE >= TARGET_SIZE_MB )); then
        break
      fi
    fi
  done < <(find . -maxdepth 1 -type f -printf '%T@ %p\0' | sort -z -n | cut -z -d' ' -f2-)

  if [ ${#FILES_TO_ARCHIVE[@]} -eq 0 ]; then
    echo "Нет подходящих файлов для архивирования"
    exit 0
  fi

  BACKUP_DIR="/backup"
  mkdir -p "$BACKUP_DIR"

ARCH_EXT="tar.gz"; TAR_CMD=(tar -czf)
if [[ "${LAB1_MAX_COMPRESSION:-0}" = "1" ]]; then
    ARCH_EXT="tar.lzma"; TAR_CMD=(tar --lzma -cf)
fi
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  ARCHIVE_NAME="$BACKUP_DIR/backup_$TIMESTAMP.$ARCH_EXT"

  echo "Архивируем ${#FILES_TO_ARCHIVE[@]} файлов в $ARCHIVE_NAME"
  "${TAR_CMD[@]}" "$ARCHIVE_NAME" "${FILES_TO_ARCHIVE[@]}"

  if [ $? -eq 0 ]; then
    echo "Архивация успешна, удаляем исходные файлы"
    rm -f "${FILES_TO_ARCHIVE[@]}"
  else
    echo "Ошибка при архивации. Удаление не выполнено."
  fi

else
  echo "Заполнение в пределах нормы, действий не требуется."
fi