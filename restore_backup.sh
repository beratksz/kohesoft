#!/bin/bash
# restore_backup.sh
# Belirli bir müşterinin yedeğini geri yükler.
# Yedek dosyaları backups/<müşteri>/ altında bulunur ve Alpine imajı ile ilgili Docker volume üzerine açılır.

set -e

read -p "Restore etmek istediğiniz müşterinin adını girin (örn: musteri1): " CUSTOMER
BACKUP_DIR="./backups/${CUSTOMER}"
if [ ! -d "${BACKUP_DIR}" ]; then
    echo "Hata: ${BACKUP_DIR} dizini bulunamadı. Bu müşteri için yedek alınmamış olabilir."
    exit 1
fi

echo "Müşteri '${CUSTOMER}' için mevcut backup dosyaları:"
ls -1 "${BACKUP_DIR}"
echo ""

# Restore seçenekleri
read -p "WordPress volume'unu (wordpress_data_${CUSTOMER}) geri yüklemek ister misiniz? (y/n): " RESTORE_WP
if [ "$RESTORE_WP" = "y" ]; then
    read -p "WordPress backup dosya adını girin (örn: wordpress_data_${CUSTOMER}_20250408_164530.tar.gz): " WP_BACKUP_FILE
    if [ ! -f "${BACKUP_DIR}/${WP_BACKUP_FILE}" ]; then
        echo "Hata: Dosya ${WP_BACKUP_FILE} bulunamadı."
        exit 1
    fi
    echo "WordPress volume geri yükleniyor..."
    docker run --rm \
      -v "wordpress_data_${CUSTOMER}":/volume \
      -v "${BACKUP_DIR}":/backup \
      alpine sh -c "cd /volume && tar xzf /backup/$(basename "$WP_BACKUP_FILE")"
    echo "WordPress volume geri yüklendi."
fi

read -p "Veritabanı (DB) volume'unu (db_data_${CUSTOMER}) geri yüklemek ister misiniz? (y/n): " RESTORE_DB
if [ "$RESTORE_DB" = "y" ]; then
    read -p "DB backup dosya adını girin (örn: db_data_${CUSTOMER}_20250408_164530.tar.gz): " DB_BACKUP_FILE
    if [ ! -f "${BACKUP_DIR}/${DB_BACKUP_FILE}" ]; then
        echo "Hata: Dosya ${DB_BACKUP_FILE} bulunamadı."
        exit 1
    fi
    echo "DB volume geri yükleniyor..."
    docker run --rm \
      -v "db_data_${CUSTOMER}":/volume \
      -v "${BACKUP_DIR}":/backup \
      alpine sh -c "cd /volume && tar xzf /backup/$(basename "$DB_BACKUP_FILE")"
    echo "DB volume geri yüklendi."
fi

echo "Restore işlemi tamamlandı. Gerekirse ilgili WP/DB container'larını yeniden başlatın."
