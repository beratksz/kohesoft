#!/bin/bash
# download_drive.sh
# Rclone ile bulut yedekleri yerel ./backups klasörüne indirir

set -euo pipefail

BACKUP_ROOT="./backups"
SOURCE="mydrive:/customer_backups"
LOG_FILE="./logs/download_$(date +%F_%H-%M-%S).log"

# Log klasörünü oluştur
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$BACKUP_ROOT"

echo "⏬ Yedek indirme işlemi başlatılıyor..." | tee -a "$LOG_FILE"

# Rclone bağlantı kontrolü
if ! rclone lsd "$SOURCE" > /dev/null 2>&1; then
  echo "❌ Bağlantı hatası: '${SOURCE}' bulunamadı veya erişilemiyor." | tee -a "$LOG_FILE"
  exit 1
fi

# İndirme işlemi
echo "📥 '${SOURCE}' → '${BACKUP_ROOT}'" | tee -a "$LOG_FILE"
rclone copy "$SOURCE" "$BACKUP_ROOT" --progress --log-file="$LOG_FILE" --log-level=INFO

echo "✅ İndirme tamamlandı. Log dosyası: $LOG_FILE"
