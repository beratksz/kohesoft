#!/bin/bash
set -e

NETWORK_NAME="wp_network"
echo "[INFO] Docker network kontrol ediliyor..."
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
  echo "[INFO] Docker network '${NETWORK_NAME}' bulunamadı, oluşturuluyor..."
  docker network create ${NETWORK_NAME}
else
  echo "[OK] Docker network '${NETWORK_NAME}' mevcut."
fi

read -p "Müşteri adını girin (örn: musteri1): " CUSTOMER
read -p "Domain ismini girin (örn: musteri1.com): " DOMAIN

# Veritabanı için rastgele ya da sabit user/pass
WP_DB_NAME="wp_db_${CUSTOMER}"
WP_DB_USER="wp_user_${CUSTOMER}"
WP_DB_PASS="wp_pass_${CUSTOMER}"
ROOT_PASS="root_pass_${CUSTOMER}"

COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"

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
      VIRTUAL_HOST: "${DOMAIN}"
      LETSENCRYPT_HOST: "${DOMAIN}"
      LETSENCRYPT_EMAIL: "admin@${DOMAIN}"

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
  db_data_${CUSTOMER}:

networks:
  ${NETWORK_NAME}:
    external: true
EOF

echo "[OK] Docker Compose dosyası '${COMPOSE_FILE}' oluşturuldu."
echo "[INFO] WordPress ve DB container'ları başlatılıyor..."
docker compose -f "${COMPOSE_FILE}" up -d

echo "[INFO] Reverse-proxy ve Let’s Encrypt companion'ın çalıştığından emin olun."
echo -e "\n✅ Tüm işlemler tamamlandı. '${CUSTOMER}' (Domain: ${DOMAIN}) eklendi."
