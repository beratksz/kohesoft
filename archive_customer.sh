#!/bin/bash
# archive_customer.sh
# Belirtilen müşteriye ait WP & DB container'larını durdurur, docker-compose ve Nginx konfigürasyon dosyalarını arşivleyerek soft deletion yapar.

set -euo pipefail

read -rp "📦 Arşivlemek istediğiniz müşterinin adını girin (örn: musteri1): " CUSTOMER

COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"
NGINX_CONF_FILE="nginx/conf.d/${CUSTOMER}.conf"
VHOST_CONF_FILE="nginx/vhost.d/${CUSTOMER}"
CERT_DIR="nginx/certs/${CUSTOMER}"

ARCHIVE_DIR="./archived_customers/${CUSTOMER}"
mkdir -p "${ARCHIVE_DIR}"

# 1. Docker Compose dosyası var mı?
if [ ! -f "${COMPOSE_FILE}" ]; then
    echo "❌ Hata: ${COMPOSE_FILE} bulunamadı."
    exit 1
fi

echo "⛔ '${CUSTOMER}' container'ları durduruluyor..."
docker compose -f "${COMPOSE_FILE}" down

# 2. Dosyaları taşı
echo "📁 Docker Compose dosyası taşınıyor..."
mv "${COMPOSE_FILE}" "${ARCHIVE_DIR}/"

echo "📁 Nginx .conf dosyası taşınıyor (varsa)..."
[ -f "${NGINX_CONF_FILE}" ] && mv "${NGINX_CONF_FILE}" "${ARCHIVE_DIR}/"

echo "📁 Nginx vhost.d klasörü taşınıyor (varsa)..."
[ -d "${VHOST_CONF_FILE}" ] && mv "${VHOST_CONF_FILE}" "${ARCHIVE_DIR}/"

echo "📁 SSL sertifikaları taşınıyor (varsa)..."
[ -d "${CERT_DIR}" ] && mv "${CERT_DIR}" "${ARCHIVE_DIR}/"

echo "🔄 Nginx proxy yeniden yükleniyor..."
docker exec nginx-proxy nginx -s reload || echo "⚠️ Nginx reload başarısız olabilir, elle kontrol et."

echo "✅ '${CUSTOMER}' başarıyla arşivlendi. Tüm dosyalar '${ARCHIVE_DIR}' altına taşındı."
