#!/bin/bash
# delete_customer.sh
# Belirtilen müşteriyi sistemden kalıcı olarak siler.
# Container'lar, konfigürasyon dosyaları ve (opsiyonel) volume'lar tamamen kaldırılır.

set -e

read -p "Kalıcı olarak silmek istediğiniz müşterinin adını girin (örn: musteri1): " CUSTOMER
COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"
NGINX_CONF_FILE="nginx_conf/${CUSTOMER}.conf"

echo "Müşteri '${CUSTOMER}' kalıcı olarak siliniyor..."

# Container'ları durdur ve kaldır (volume'lar dahil --volumes)
if [ -f "${COMPOSE_FILE}" ]; then
    docker compose -f "${COMPOSE_FILE}" down --volumes
    rm -f "${COMPOSE_FILE}"
else
    echo "Uyarı: Docker Compose dosyası bulunamadı."
fi

# Nginx konfigürasyon dosyasını sil
if [ -f "${NGINX_CONF_FILE}" ]; then
    rm -f "${NGINX_CONF_FILE}"
fi

# Volume'ları silmek için ek kontrol
echo "Müşteri ile ilişkili volume'ları görüntüleyin:"
docker volume ls | grep "${CUSTOMER}"
read -p "Volume'ları silmek istiyor musunuz? (y/n): " CONFIRM
if [ "$CONFIRM" = "y" ]; then
    docker volume rm $(docker volume ls | awk "/${CUSTOMER}/ {print \$2}")
fi

echo "Müşteri '${CUSTOMER}' kalıcı olarak sistemden silindi."
