#!/bin/bash

DISK_IMG="virtual_disk.img"
MOUNT_POINT="./mnt"

umount "$MOUNT_POINT"
rm -rf "$MOUNT_POINT" "$DISK_IMG"
mkdir -p "$MOUNT_POINT"

dd if=/dev/zero of="$DISK_IMG" bs=1M count=1024 status=none

mkfs -t ext4 "$DISK_IMG"

mount -o loop "$DISK_IMG" "$MOUNT_POINT"

mkdir -p "$MOUNT_POINT/log"
mkdir -p "$MOUNT_POINT/backup"

create_file() {
  local filename=$1
  local size_mb=$2
  local mod_time=$3
  dd if=/dev/urandom of="$MOUNT_POINT/log/$filename" bs=1M count=$size_mb status=none
  touch -m -d "$mod_time" "$MOUNT_POINT/log/$filename"
}

echo "Создаём тестовые файлы на виртуальном диске..."

create_file "old_file1.bin" 100 "$(LC_TIME=C date -d '10 days ago')" 
create_file "old_file2.bin" 150 "$(LC_TIME=C date -d '9 days ago')" 
create_file "mid_file.bin" 150 "$(LC_TIME=C date -d '5 days ago')" 
create_file "new_file.bin" 120 "$(LC_TIME=C date -d '1 day ago')" 

echo "Размер каталога логов до запуска:"
du -sh "$MOUNT_POINT/log"

echo "Содержимое каталога /log:"
ls -lh "$MOUNT_POINT/log"

echo "Запуск основного скрипта..."
./script.sh "$MOUNT_POINT/log" 50

echo "Размер каталога логов после запуска:"
du -sh "$MOUNT_POINT/log"

echo "Содержимое каталога /log:"
ls -lh "$MOUNT_POINT/log"

sudo umount "$MOUNT_POINT"
rm -rf "$MOUNT_POINT" "$DISK_IMG"
