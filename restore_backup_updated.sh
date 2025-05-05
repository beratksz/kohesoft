#!/bin/bash
# restore_backup.sh
# Belirli bir müşterinin WordPress ve MySQL yedeklerini Docker volume'larına
# - Container’ları durdurup
# - Volume’ları tarball’dan --strip-components=1 ile geri yükleyip
# - İzinleri ve InnoDB redo-log temizliği yaptıktan sonra
# - Container’ları yeniden ayağa kaldırır

set -euo pipefail

# 1️⃣ Kullanıcı girişi ve dosya tanımlamaları
read -rp "🔁 Restore etmek istediğiniz müşteri adı (örn: musteri1): " CUSTOMER
COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"
BACKUP_DIR="./backups/${CUSTOMER}"
LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/restore_${CUSTOMER}_$(date +%F_%H-%M-%S).log"

# Log dizini ve yedek klasörü kontrolleri
mkdir -p "${LOG_DIR}"
if [ ! -d "${BACKUP_DIR}" ]; then
  echo "❌ Hata: Yedek klasörü bulunamadı: ${BACKUP_DIR}" | tee -a "${LOG_FILE}"
  exit 1
fi

# Tüm çıktı log’a da yazılsın
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "📅 Başlangıç: $(date)"
echo "🗂️  Yedekler: ${BACKUP_DIR}"
ls -lh "${BACKUP_DIR}"
echo

# 2️⃣ Container’ları durdur
echo "⏹️  Container’lar durduruluyor..."
docker compose -f "${COMPOSE_FILE}" down

# 3️⃣ WordPress volume restore
read -rp "📦 WordPress yedeğini geri yüklensin mi? (y/n): " DO_WP
if [[ "${DO_WP,,}" == "y" ]]; then
  read -rp "🗃️ WP yedek dosya adı: " WP_TAR
  echo "🔄 WordPress yedeği yükleniyor..."
  docker run --rm \
    -v "wordpress_data_${CUSTOMER}:/data" \
    -v "${BACKUP_DIR}:/backup:ro" \
    alpine sh -c "cd /data && tar xzvf /backup/${WP_TAR} --strip-components=1"
  echo "✅ WordPress yedeği yüklendi."
fi

# 4️⃣ MySQL volume restore
read -rp $'\n📦 Veritabanı yedeğini geri yüklensin mi? (y/n): ' DO_DB
if [[ "${DO_DB,,}" == "y" ]]; then
  read -rp "🗃️ DB yedek dosya adı: " DB_TAR
  echo "🔄 Veritabanı yedeği yükleniyor..."
  docker run --rm \
    -v "db_data_${CUSTOMER}:/data" \
    -v "${BACKUP_DIR}:/backup:ro" \
    alpine sh -c "cd /data && tar xzvf /backup/${DB_TAR} --strip-components=1"
  echo "✅ Veritabanı yedeği yüklendi."

  # 4a️⃣ İzinleri düzelt
  echo "🔧 MySQL veri izinleri düzeltiliyor..."
  docker run --rm \
    -v "db_data_${CUSTOMER}:/data" \
    alpine sh -c "chown -R 999:999 /data"

  # 4b️⃣ InnoDB redo-log dosyalarını temizle
  echo "🧹 InnoDB redo-log dosyaları temizleniyor..."
  docker run --rm \
    -v "db_data_${CUSTOMER}:/data" \
    alpine sh -c "rm -rf /data/#innodb_redo && rm -f /data/ib_logfile*"

  # 4c️⃣ Redo-log dizinini yeniden oluştur
  echo "📁 Redo-log dizini oluşturuluyor ve izin ayarlanıyor..."
  docker run --rm \
    -v "db_data_${CUSTOMER}:/data" \
    alpine sh -c "mkdir -p /data/#innodb_redo && chown -R 999:999 /data/#innodb_redo"
fi

# 5️⃣ Container’ları yeniden ayağa kaldır
echo -e "\n🚀 Container’lar başlatılıyor..."
docker compose -f "${COMPOSE_FILE}" up -d --force-recreate --renew-anon-volumes

echo -e "\n🎉 Restore tamamlandı: $(date)"
echo "📝 Log dosyası: ${LOG_FILE}"
