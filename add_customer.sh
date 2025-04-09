#!/bin/bash
# add_customer.sh
# Yeni müşteri eklemek için; WP & DB container'larını oluşturur, docker-compose dosyası ve Nginx konfigürasyonunu üretir.

set -e

# 1. Docker network kontrolü
NETWORK_NAME="wp_network"
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}\$"; then
  echo "Docker network '${NETWORK_NAME}' oluşturuluyor..."
  docker network create ${NETWORK_NAME}
else
  echo "Docker network '${NETWORK_NAME}' zaten var."
fi

# 2. Müşteri bilgilerini al
read -p "Müşteri adını girin (örn: musteri1): " CUSTOMER
read -p "Port son ekini girin (örn: 01, 02 vs.): " PORT_SUFFIX
read -p "Domain ismini girin (örn: musteri1.ornekdomain.com): " DOMAIN

# Veritabanı ayarları
WP_DB_NAME="wp_db_${CUSTOMER}"
WP_DB_USER="wp_user_${CUSTOMER}"
WP_DB_PASS="wp_pass_${CUSTOMER}"
ROOT_PASS="root_pass_${CUSTOMER}"

# 3. Docker Compose dosyasını oluştur (WP & DB)
COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"

cat > "${COMPOSE_FILE}" <<EOF
version: '3.8'
services:
  wordpress_${CUSTOMER}:
    image: wordpress:latest
    container_name: wordpress_${CUSTOMER}
    restart: always
    ports:
      - "80${PORT_SUFFIX}:80"
    environment:
      WORDPRESS_DB_HOST: db_${CUSTOMER}:3306
      WORDPRESS_DB_USER: ${WP_DB_USER}
      WORDPRESS_DB_PASSWORD: ${WP_DB_PASS}
      WORDPRESS_DB_NAME: ${WP_DB_NAME}
    volumes:
      - wordpress_data_${CUSTOMER}:/var/www/html
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - db_${CUSTOMER}

  db_${CUSTOMER}:
    image: mysql:5.7
    container_name: db_${CUSTOMER}
    restart: always
    environment:
      MYSQL_DATABASE: ${WP_DB_NAME}
      MYSQL_USER: ${WP_DB_USER}
      MYSQL_PASSWORD: ${WP_DB_PASS}
      MYSQL_ROOT_PASSWORD: ${ROOT_PASS}
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

echo "Docker Compose dosyası '${COMPOSE_FILE}' oluşturuldu."
docker compose -f "${COMPOSE_FILE}" up -d

# 4. Nginx konfigürasyon dosyası oluştur (nginx_conf altına)
NGINX_CONF_DIR="./nginx_conf"
mkdir -p "${NGINX_CONF_DIR}"
NGINX_CONF_FILE="${NGINX_CONF_DIR}/${CUSTOMER}.conf"

cat > "${NGINX_CONF_FILE}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://wordpress_${CUSTOMER}:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "Nginx konfigürasyon dosyası oluşturuldu: ${NGINX_CONF_FILE}"
echo "Müşteri ${CUSTOMER} başarıyla eklenmiştir."
