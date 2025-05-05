#!/bin/bash
# archive_customer.sh
# Belirtilen müşteriye ait WP & DB container'larını durdurur, docker-compose ve Nginx konfigürasyon dosyalarını,
# hem klasörlü hem de flat sertifika modellerini arşivleyerek soft deletion yapar.

set -euo pipefail

read -rp "📦 Arşivlemek istediğiniz müşterinin adını girin (örn: musteri1): " CUSTOMER

COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"
NGINX_CONF_FILE="nginx/conf.d/${CUSTOMER}.conf"
VHOST_CONF_DIR="nginx/vhost.d/${CUSTOMER}"
CERT_BASE="nginx/certs"
CERT_FOLDER="${CERT_BASE}/${CUSTOMER}"

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

echo "📁 Nginx conf dosyası taşınıyor (varsa)..."
if [ -f "${NGINX_CONF_FILE}" ]; then
    mv "${NGINX_CONF_FILE}" "${ARCHIVE_DIR}/"
fi

echo "📁 Nginx vhost.d klasörü taşınıyor (varsa)..."
if [ -d "${VHOST_CONF_DIR}" ]; then
    mv "${VHOST_CONF_DIR}" "${ARCHIVE_DIR}/"
fi

# 3. Klasörlü sertifikaları taşı
echo "📁 SSL sertifika klasörü taşınıyor (varsa)..."
if [ -d "${CERT_FOLDER}" ]; then
    mv "${CERT_FOLDER}" "${ARCHIVE_DIR}/"
fi

# 4. Flat sertifika dosyalarını taşı
echo "📁 Flat SSL sertifika dosyaları taşınıyor (varsa)..."
for ext in crt key chain.pem dhparam.pem; do
    SRC="${CERT_BASE}/${CUSTOMER}.${ext}"
    if [ -f "${SRC}" ]; then
        mv "${SRC}" "${ARCHIVE_DIR}/"
    fi
done

# 5. Nginx proxy reload
echo "🔄 Nginx proxy yeniden yükleniyor..."
docker exec nginx-proxy nginx -s reload || echo "⚠️ Nginx reload başarısız olabilir, elle kontrol et."

echo "✅ '${CUSTOMER}' başarıyla arşivlendi. Tüm dosyalar '${ARCHIVE_DIR}' altına taşındı."
