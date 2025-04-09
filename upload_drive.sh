#!/bin/bash
# upload_drive.sh
# Bu script, yerel backups klasöründeki yedekleri rclone kullanarak bulut ortamına (örneğin, Google Drive) yükler.

set -e

BACKUP_ROOT="./backups"
DESTINATION="mydrive:/customer_backups"  # Rclone konfigürasyonunuzda ayarlanan remote ismi ve hedef klasör

echo "Yerel backup'lar ${BACKUP_ROOT} klasöründen ${DESTINATION} konumuna yüklenecek..."
rclone copy "${BACKUP_ROOT}" "${DESTINATION}" --progress

echo "Yedekler başarıyla yüklendi."
