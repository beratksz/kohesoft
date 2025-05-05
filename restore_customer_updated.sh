#!/bin/bash
# restore_customer.sh
# archived_customers altındaki bir müşteriyi "unarchive" eder:
#  - Dosyaları orijinal konumlarına taşır
#  - Docker Compose container'larını başlatır
#  - Nginx proxy'yi yeniden yükler

set -euo pipefail

read -rp "🔄 Geri yüklemek istediğiniz müşterinin adını girin (örn: musteri1): " CUSTOMER

ARCHIVE_DIR="./archived_customers/${CUSTOMER}"
COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"
NGINX_CONF_FILE="nginx/conf.d/${CUSTOMER}.conf"
VHOST_CONF_DIR="nginx/vhost.d/${CUSTOMER}"
CERT_BASE="nginx/certs"
CERT_DIR="${CERT_BASE}/${CUSTOMER}"

# 1. Arşiv var mı?
if [ ! -d "${ARCHIVE_DIR}" ]; then
    echo "❌ Hata: ${ARCHIVE_DIR} bulunamadı. Arşivlenmiş müşteri yok."
    exit 1
fi
echo "📂 Arşivden alınıyor: ${ARCHIVE_DIR}"

# 2. Docker Compose dosyasını geri taşı
if [ -f "${ARCHIVE_DIR}/${COMPOSE_FILE}" ]; then
    mv "${ARCHIVE_DIR}/${COMPOSE_FILE}" ./
    echo "✅ ${COMPOSE_FILE} geri alındı."
else
    echo "⚠️ ${COMPOSE_FILE} arşivde yok."
fi

# 3. Nginx conf dosyasını geri taşı
if [ -f "${ARCHIVE_DIR}/$(basename "${NGINX_CONF_FILE}")" ]; then
    mv "${ARCHIVE_DIR}/$(basename "${NGINX_CONF_FILE}")" "nginx/conf.d/"
    echo "✅ nginx/conf.d/${CUSTOMER}.conf geri alındı."
else
    echo "⚠️ nginx/conf.d/${CUSTOMER}.conf arşivde yok."
fi

# 4. vhost.d klasörünü geri taşı
if [ -d "${ARCHIVE_DIR}/$(basename "${VHOST_CONF_DIR}")" ]; then
    mv "${ARCHIVE_DIR}/$(basename "${VHOST_CONF_DIR}")" "nginx/vhost.d/"
    echo "✅ nginx/vhost.d/${CUSTOMER} klasörü geri alındı."
else
    echo "⚠️ nginx/vhost.d/${CUSTOMER} klasörü arşivde yok."
fi

# 5. SSL sertifikalarını geri taşı
echo "📁 SSL sertifikaları geri yükleniyor..."
# Klasörlü model varsa
if [ -d "${ARCHIVE_DIR}/${CUSTOMER}" ]; then
    mv "${ARCHIVE_DIR}/${CUSTOMER}" "${CERT_BASE}/"
    echo "✅ ${CERT_DIR} klasörü geri alındı."
else
    # Flat dosyalar üzerinden klasör oluşturup taşı
    mkdir -p "${CERT_DIR}"
    for ext in crt key chain.pem dhparam.pem; do
        SRC="${ARCHIVE_DIR}/${CUSTOMER}.${ext}"
        if [ -f "$SRC" ]; then
            case "$ext" in
                crt)       DST="cert.pem"    ;;
                key)       DST="key.pem"     ;;
                chain.pem) DST="chain.pem"   ;;
                dhparam.pem) DST="dhparam.pem";;
            esac
            mv "$SRC" "${CERT_DIR}/${DST}"
            echo "✅ ${DST} geri alındı."
        fi
    done
fi

# 6. Arşiv klasörünü temizle (opsiyonel, boşsa silinir)
if [ -z "$(ls -A "${ARCHIVE_DIR}")" ]; then
    rmdir "${ARCHIVE_DIR}"
    echo "🗑️ Boş arşiv klasörü silindi: ${ARCHIVE_DIR}"
else
    echo "⚠️ ${ARCHIVE_DIR} altında hâlâ dosya var, kontrol et."
fi

# 7. Container'ları ayağa kaldır
if [ -f "./${COMPOSE_FILE}" ]; then
    echo "🚀 Docker Compose container'ları başlatılıyor..."
    docker compose -f "${COMPOSE_FILE}" up -d
else
    echo "⚠️ Docker Compose dosyası yok, container’lar başlatılamadı."
fi

# 8. Nginx proxy reload
echo "🔄 Nginx proxy yeniden yükleniyor..."
docker exec nginx-proxy nginx -s reload || echo "⚠️ Nginx reload başarısız. Elle kontrol et."

echo "🎉 '${CUSTOMER}' başarıyla geri yüklendi!"
