#!/bin/bash
# archive_customer.sh
# Belirtilen müşteriye ait WP & DB container'larını durdurur, docker-compose ve Nginx konfigürasyon dosyalarını arşivleyerek soft deletion yapar.

set -e

read -p "Arşivlemek istediğiniz müşterinin adını girin (örn: musteri1): " CUSTOMER
COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"
NGINX_CONF_FILE="nginx_conf/${CUSTOMER}.conf"

if [ ! -f "${COMPOSE_FILE}" ]; then
    echo "Hata: ${COMPOSE_FILE} bulunamadı."
    exit 1
fi

echo "Müşteri '${CUSTOMER}' arşivleniyor..."

# 1. Container'ları durdur ve kaldır (volume'lar korunur)
docker compose -f "${COMPOSE_FILE}" down

# 2. Arşiv klasörünü oluştur ve dosyaları taşı
ARCHIVE_DIR="./archived_customers/${CUSTOMER}"
mkdir -p "${ARCHIVE_DIR}"

mv "${COMPOSE_FILE}" "${ARCHIVE_DIR}/"
if [ -f "${NGINX_CONF_FILE}" ]; then
    mv "${NGINX_CONF_FILE}" "${ARCHIVE_DIR}/"
fi

echo "Müşteri '${CUSTOMER}' arşivlendi. Docker Compose ve Nginx dosyaları '${ARCHIVE_DIR}' altına taşındı."
