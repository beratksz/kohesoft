#!/bin/bash
# download_drive.sh
# Bu script, rclone kullanarak bulut ortamındaki yedekleri (örneğin, Google Drive) yerel backups klasörüne indirir.

set -e

BACKUP_ROOT="./backups"
DESTINATION="mydrive:/customer_backups"  # Rclone remote isminiz ve hedef klasör

echo "Bulut ortamındaki backup'lar ${DESTINATION}'dan yerel ${BACKUP_ROOT} klasörüne indiriliyor..."
rclone copy "${DESTINATION}" "${BACKUP_ROOT}" --progress

echo "Download işlemi tamamlandı. Yedekler ${BACKUP_ROOT} dizininde yer alıyor."
