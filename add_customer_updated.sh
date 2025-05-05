#!/bin/bash
set -euo pipefail

NETWORK_NAME="wp_network"
echo "[INFO] Docker network kontrol ediliyor..."
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
  echo "[INFO] Docker ağı '${NETWORK_NAME}' oluşturuluyor..."
  docker network create ${NETWORK_NAME}
else
  echo "[OK] Docker ağı zaten mevcut."
fi

read -p "👤 Müşteri adı (örn: musteri1): " CUSTOMER
read -p "🌍 Domain (örn: musteri1.com): " DOMAIN

echo "🔐 SSL türünü seçin:"
echo "1) Let's Encrypt (ücretsiz)"
echo "2) Manuel SSL (crt/key/ca-bundle)"
read -p "Seçimin (1/2): " SSL_TYPE

# DB Bilgileri
WP_DB_NAME="wp_db_${CUSTOMER}"
WP_DB_USER="wp_user_${CUSTOMER}"
WP_DB_PASS="wp_pass_${CUSTOMER}"
ROOT_PASS="root_pass_${CUSTOMER}"
COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"

# Sertifika environment satırları
if [[ "$SSL_TYPE" == "1" ]]; then
  CERT_LINE=$(cat <<EOF
      VIRTUAL_HOST: "${DOMAIN}"
      LETSENCRYPT_HOST: "${DOMAIN}"
      LETSENCRYPT_EMAIL: "admin@${DOMAIN}"
      CERT_NAME: "${DOMAIN}"
EOF
)
elif [[ "$SSL_TYPE" == "2" ]]; then
  # Manuel SSL klasörlü modele göre kopyala
  echo "📄 Sertifika dosyasının tam yolu (örn: kohesoft.crt):"
  read -rp "> " CERT_FILE
  echo "🔑 Özel anahtar dosyası yolu (örn: kohesoft.key):"
  read -rp "> " KEY_FILE
  echo "📎 CA bundle dosyası yolu (örn: ca-bundle.crt):"
  read -rp "> " BUNDLE_FILE

  CERT_DIR="./nginx/certs/${DOMAIN}"
  mkdir -p "${CERT_DIR}"

  cp "$CERT_FILE"   "${CERT_DIR}/cert.pem"
  cp "$KEY_FILE"    "${CERT_DIR}/key.pem"
  cp "$BUNDLE_FILE" "${CERT_DIR}/chain.pem"

  CERT_LINE=$(cat <<EOF
      VIRTUAL_HOST: "${DOMAIN}"
      VIRTUAL_PORT: "80"
      CERT_NAME: "${DOMAIN}"
EOF
)
else
  echo "❌ Geçersiz SSL seçimi. Çıkılıyor."
  exit 1
fi

# Docker Compose dosyası oluştur
cat > "${COMPOSE_FILE}" <<EOF
version: '3.8'

services:
  wordpress_${CUSTOMER}:
    image: wordpress:latest
    container_name: wordpress_${CUSTOMER}
    restart: always
    expose:
      - "80"
    environment:
$CERT_LINE
      WORDPRESS_DB_HOST: "db_${CUSTOMER}:3306"
      WORDPRESS_DB_USER: "${WP_DB_USER}"
      WORDPRESS_DB_PASSWORD: "${WP_DB_PASS}"
      WORDPRESS_DB_NAME: "${WP_DB_NAME}"
    volumes:
      - wordpress_data_${CUSTOMER}:/var/www/html
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - db_${CUSTOMER}

  db_${CUSTOMER}:
    image: mysql:8
    container_name: db_${CUSTOMER}
    restart: always
    environment:
      MYSQL_DATABASE: "${WP_DB_NAME}"
      MYSQL_USER: "${WP_DB_USER}"
      MYSQL_PASSWORD: "${WP_DB_PASS}"
      MYSQL_ROOT_PASSWORD: "${ROOT_PASS}"
    volumes:
      - db_data_${CUSTOMER}:/var/lib/mysql
    networks:
      - ${NETWORK_NAME}

volumes:
  wordpress_data_${CUSTOMER}:
    name: wordpress_data_${CUSTOMER}
  db_data_${CUSTOMER}:
    name: db_data_${CUSTOMER}

networks:
  ${NETWORK_NAME}:
    external: true
EOF

echo "[OK] Docker Compose dosyası '${COMPOSE_FILE}' oluşturuldu."
echo "[INFO] Container'lar başlatılıyor..."
docker compose -f "${COMPOSE_FILE}" up -d

# Let's Encrypt seçildiyse flat → klasöre taşı
if [[ "$SSL_TYPE" == "1" ]]; then
  CERT_DIR="./nginx/certs/${DOMAIN}"
  mkdir -p "${CERT_DIR}"
  echo "[INFO] Let's Encrypt sertifikaları klasöre taşınıyor..."
  # issuance için küçük bekleme
  sleep 5
  for ext in crt key chain.pem dhparam.pem; do
    SRC="./nginx/certs/${DOMAIN}.${ext}"
    DST="${CERT_DIR}/${ext/chain.pem/chain.pem}"
    if [ -f "$SRC" ]; then
      mv "$SRC" "$DST"
    fi
  done
  # normalize
  mv "${CERT_DIR}/${DOMAIN}.crt"      "${CERT_DIR}/cert.pem"    2>/dev/null || true
  mv "${CERT_DIR}/${DOMAIN}.key"      "${CERT_DIR}/key.pem"     2>/dev/null || true
  mv "${CERT_DIR}/${DOMAIN}.chain.pem" "${CERT_DIR}/chain.pem"   2>/dev/null || true
  mv "${CERT_DIR}/${DOMAIN}.dhparam.pem" "${CERT_DIR}/dhparam.pem" 2>/dev/null || true

  echo "📢 Let's Encrypt sertifikaları hazır: ${CERT_DIR}/"
else
  echo "📢 Manuel sertifikalar yüklendi: ./nginx/certs/${DOMAIN}/"
fi

# Nginx-proxy reload
echo "[INFO] Nginx-proxy yeniden yükleniyor..."
docker exec nginx-proxy nginx -s reload || true

echo -e "\n✅ '${CUSTOMER}' başarıyla eklendi (Domain: ${DOMAIN})"
