#!/bin/bash
# backup_customers.sh
# Tüm müşterilerin WP & DB volume yedeklerini alır.
# Her müşteri için backups/<müşteri>/ altında tar.gz formatında yedekler oluşturur.

set -e

BACKUP_ROOT="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
mkdir -p "$BACKUP_ROOT"

# Mevcut dizinde docker-compose-*.yml dosyalarını tarar
for file in docker-compose-*.yml; do
    CUSTOMER=$(basename "$file")
    CUSTOMER=${CUSTOMER#docker-compose-}
    CUSTOMER=${CUSTOMER%.yml}

    echo "Müşteri: $CUSTOMER için yedekleme yapılıyor..."
    CUSTOMER_BACKUP_DIR="$BACKUP_ROOT/$CUSTOMER"
    mkdir -p "$CUSTOMER_BACKUP_DIR"

    WP_VOLUME="wordpress_data_${CUSTOMER}"
    WP_BACKUP_FILE="${WP_VOLUME}_${TIMESTAMP}.tar.gz"
    echo "  WordPress volume yedekleniyor: $WP_VOLUME"
    docker run --rm \
       -v "${WP_VOLUME}":/volume \
       -v "$CUSTOMER_BACKUP_DIR":/backup \
       alpine sh -c "cd /volume && tar czf /backup/$(basename "$WP_BACKUP_FILE") ."

    DB_VOLUME="db_data_${CUSTOMER}"
    DB_BACKUP_FILE="${DB_VOLUME}_${TIMESTAMP}.tar.gz"
    echo "  DB volume yedekleniyor: $DB_VOLUME"
    docker run --rm \
       -v "${DB_VOLUME}":/volume \
       -v "$CUSTOMER_BACKUP_DIR":/backup \
       alpine sh -c "cd /volume && tar czf /backup/$(basename "$DB_BACKUP_FILE") ."

    echo "  $CUSTOMER için yedekleme tamamlandı. Yedekler: $CUSTOMER_BACKUP_DIR"
done

echo "Tüm yedekleme işlemleri tamamlandı."
