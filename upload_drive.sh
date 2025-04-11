#!/bin/bash
# upload_drive.sh
# Yerel yedekleri rclone kullanarak Google Drive (veya başka bir bulut) ortamına yükler.

set -euo pipefail

BACKUP_ROOT="./backups"
DESTINATION="mydrive:/customer_backups"
LOG_FILE="./logs/upload_$(date +%F_%H-%M-%S).log"

# Log klasörü oluşturulmamışsa oluştur
mkdir -p "$(dirname "$LOG_FILE")"

echo "🚀 Yükleme işlemi başlıyor..." | tee -a "$LOG_FILE"

# Backup klasörü kontrolü
if [[ ! -d "$BACKUP_ROOT" ]]; then
  echo "❌ Hata: Yedek klasörü '$BACKUP_ROOT' bulunamadı!" | tee -a "$LOG_FILE"
  exit 1
fi

# Rclone bağlantı testi
if ! rclone lsd "$DESTINATION" > /dev/null 2>&1; then
  echo "⚠️  Hedef '${DESTINATION}' erişilemiyor. Rclone konfigürasyonunu kontrol et!" | tee -a "$LOG_FILE"
  exit 1
fi

# Yükleme işlemi
echo "📦 Yedekler '${BACKUP_ROOT}' -> '${DESTINATION}' klasörüne yükleniyor..." | tee -a "$LOG_FILE"
rclone copy "$BACKUP_ROOT" "$DESTINATION" --progress --log-file="$LOG_FILE" --log-level=INFO

echo "✅ Yükleme tamamlandı. Log dosyası: $LOG_FILE"
