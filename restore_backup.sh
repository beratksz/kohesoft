#!/bin/bash
# restore_backup.sh
# Belirli bir müşterinin WordPress ve MySQL yedeklerini Docker volume'larına geri yükler.

set -euo pipefail

read -p "🔁 Restore etmek istediğiniz müşteri adı (örn: musteri1): " CUSTOMER
BACKUP_DIR="./backups/${CUSTOMER}"
LOG_FILE="./logs/restore_${CUSTOMER}_$(date +%F_%H-%M-%S).log"

# Klasör ve log hazırlığı
mkdir -p "$(dirname "$LOG_FILE")"
if [ ! -d "$BACKUP_DIR" ]; then
  echo "❌ Hata: '${BACKUP_DIR}' klasörü yok. Yedek bulunamadı." | tee -a "$LOG_FILE"
  exit 1
fi

echo "🧾 Yedek listesi: $BACKUP_DIR" | tee -a "$LOG_FILE"
ls -lh "$BACKUP_DIR" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

## WordPress geri yükleme
read -p "📦 WordPress volume (wordpress_data_${CUSTOMER}) yedeği geri yüklensin mi? (y/n): " RESTORE_WP
if [[ "$RESTORE_WP" == "y" ]]; then
  read -p "🗃️ WP yedek dosya adı: " WP_BACKUP_FILE
  if [[ ! -f "${BACKUP_DIR}/${WP_BACKUP_FILE}" ]]; then
    echo "❌ Hata: '${WP_BACKUP_FILE}' dosyası bulunamadı." | tee -a "$LOG_FILE"
    exit 1
  fi
  echo "🔄 WordPress yedeği geri yükleniyor..." | tee -a "$LOG_FILE"
  docker run --rm \
    -v "wordpress_data_${CUSTOMER}":/volume \
    -v "$BACKUP_DIR":/backup \
    alpine sh -c "cd /volume && tar xzf /backup/$(basename "$WP_BACKUP_FILE")"
  echo "✅ WordPress yedeği geri yüklendi." | tee -a "$LOG_FILE"
fi

## DB geri yükleme
read -p "📦 Veritabanı volume (db_data_${CUSTOMER}) yedeği geri yüklensin mi? (y/n): " RESTORE_DB
if [[ "$RESTORE_DB" == "y" ]]; then
  read -p "🗃️ DB yedek dosya adı: " DB_BACKUP_FILE
  if [[ ! -f "${BACKUP_DIR}/${DB_BACKUP_FILE}" ]]; then
    echo "❌ Hata: '${DB_BACKUP_FILE}' dosyası bulunamadı." | tee -a "$LOG_FILE"
    exit 1
  fi
  echo "🔄 Veritabanı yedeği geri yükleniyor..." | tee -a "$LOG_FILE"
  docker run --rm \
    -v "db_data_${CUSTOMER}":/volume \
    -v "$BACKUP_DIR":/backup \
    alpine sh -c "cd /volume && tar xzf /backup/$(basename "$DB_BACKUP_FILE")"
  echo "✅ Veritabanı yedeği geri yüklendi." | tee -a "$LOG_FILE"
fi

echo ""
echo "🚀 Yedekleme geri yüklendi. Dilersen şunu çalıştır:"
echo "  docker compose -f docker-compose-${CUSTOMER}.yml up -d"
echo "📝 Log: $LOG_FILE"
