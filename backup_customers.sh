#!/bin/bash
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

for wp_container in $(docker ps --format '{{.Names}}' | grep wordpress_); do
  customer=${wp_container#wordpress_}
  docker run --rm --volumes-from $wp_container -v $BACKUP_DIR:/backup busybox tar czf /backup/${customer}_wp.tar.gz /var/www/html
  docker exec db_${customer} sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' > $BACKUP_DIR/${customer}_db.sql
done

echo "📦 Yedekleme tamamlandı: $BACKUP_DIR"
