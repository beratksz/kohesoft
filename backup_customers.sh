#!/bin/bash
# backup_customers.sh
# Tüm müşterilerin WordPress ve DB volume'larını timestamp'li .tar.gz olarak yedekler.
# Yedekler ./backups/<müşteri>/<volume>_tarih_saat.tar.gz formatında tutulur.

set -euo pipefail

BACKUP_ROOT="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
mkdir -p "$BACKUP_ROOT"

# Docker volume var mı kontrolü
check_volume_exists() {
  local vol=$1
  docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"
}

echo -e "\n📦 Yedekleme işlemi başlatıldı: $TIMESTAMP\n"

# docker-compose-*.yml taranıyor
shopt -s nullglob
for file in docker-compose-*.yml; do
  CUSTOMER="${file#docker-compose-}"
  CUSTOMER="${CUSTOMER%.yml}"
  echo "🧾 Müşteri: $CUSTOMER"

  CUSTOMER_BACKUP_DIR="${BACKUP_ROOT}/${CUSTOMER}"
  mkdir -p "${CUSTOMER_BACKUP_DIR}"

  # WordPress Volume
  WP_VOL="wordpress_data_${CUSTOMER}"
  WP_FILE="${WP_VOL}_${TIMESTAMP}.tar.gz"

  if check_volume_exists "$WP_VOL"; then
    echo "  📝 WordPress verisi yedekleniyor..."
    docker run --rm \
      -v "${WP_VOL}:/volume" \
      -v "${CUSTOMER_BACKUP_DIR}:/backup" \
      alpine sh -c "cd /volume && tar czf /backup/${WP_FILE} ."
  else
    echo "  ⚠️ Volume bulunamadı: $WP_VOL"
  fi

  # MySQL Volume
  DB_VOL="db_data_${CUSTOMER}"
  DB_FILE="${DB_VOL}_${TIMESTAMP}.tar.gz"

  if check_volume_exists "$DB_VOL"; then
    echo "  📝 DB verisi yedekleniyor..."
    docker run --rm \
      -v "${DB_VOL}:/volume" \
      -v "${CUSTOMER_BACKUP_DIR}:/backup" \
      alpine sh -c "cd /volume && tar czf /backup/${DB_FILE} ."
  else
    echo "  ⚠️ Volume bulunamadı: $DB_VOL"
  fi

  echo "✅ Yedekleme tamamlandı: ${CUSTOMER_BACKUP_DIR}"
  echo "--------------------------------------------------"
done

echo -e "\n🎉 Tüm yedekleme işlemleri başarıyla tamamlandı!\n"
