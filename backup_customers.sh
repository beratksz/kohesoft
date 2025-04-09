#!/bin/bash
read -p "Müşteri adı: " CUSTOMER
read -p "Yedek klasörü: " BACKUP_DIR

docker compose -f docker-compose-${CUSTOMER}.yml down
docker compose -f docker-compose-${CUSTOMER}.yml up -d db_${CUSTOMER}

docker exec -i db_${CUSTOMER} mysql -uroot -p"root_pass_${CUSTOMER}" < ${BACKUP_DIR}/${CUSTOMER}_db.sql

docker run --rm --volumes-from wordpress_${CUSTOMER} -v ${BACKUP_DIR}:/backup busybox sh -c "rm -rf /var/www/html/* && tar xzf /backup/${CUSTOMER}_wp.tar.gz -C /"

docker compose -f docker-compose-${CUSTOMER}.yml up -d

echo "🔄 Müşteri '${CUSTOMER}' geri yüklendi."
