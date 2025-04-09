#!/bin/bash
# add_setup.sh
# SSL destekli olarak yeni bir müşteri ekler.
#   1) WordPress & DB container'ını oluşturur.
#   2) Müşteri için docker-compose dosyasını üretir.
#   3) Repo kökündeki ./nginx_conf dizininde müşteriye özel Nginx konfigürasyon dosyası oluşturur.
#   4) Reverse proxy container'ını kontrol eder; çalışmıyorsa başlatır, çalışıyorsa reload eder.
#   5) SSL sertifikası yoksa HTTP ile devam eder, istenirse otomatik SSL (Certbot) kurar.

set -e

NETWORK_NAME="wp_network"
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
  echo "Docker network '${NETWORK_NAME}' bulunamadı. Oluşturuluyor..."
  docker network create ${NETWORK_NAME}
else
  echo "Docker network '${NETWORK_NAME}' zaten mevcut."
fi

read -p "Müşteri adını girin (\u00f6rn: musteri1): " CUSTOMER
read -p "Port son ekini girin (\u00f6rn: 01,02 vs.): " PORT_SUFFIX
read -p "Domain ismini girin (\u00f6rn: musteri1.com): " DOMAIN

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
echo "WordPress ve DB container'ı başlatılıyor..."
docker compose -f "${COMPOSE_FILE}" up -d

NGINX_CONF_DIR="./nginx_conf"
mkdir -p "${NGINX_CONF_DIR}"
NGINX_CONF_FILE="${NGINX_CONF_DIR}/${CUSTOMER}.conf"

CERT_PATH="/etc/nginx/ssl/${CUSTOMER}.crt"
KEY_PATH="/etc/nginx/ssl/${CUSTOMER}.key"

if [[ -f "/root/kohesoft/nginx_ssl/${CUSTOMER}.crt" && -f "/root/kohesoft/nginx_ssl/${CUSTOMER}.key" ]]; then
  SSL_BLOCK="ssl_certificate     ${CERT_PATH};\n    ssl_certificate_key ${KEY_PATH};\n    ssl_session_cache   shared:SSL:1m;\n    ssl_session_timeout 10m;\n    ssl_ciphers         HIGH:!aNULL:!MD5;\n    ssl_prefer_server_ciphers on;"
else
  echo "Uyarı: ${CUSTOMER} için SSL sertifikası bulunamadı."
  read -p "Otomatik SSL sertifikası almak ister misiniz? (y/n): " AUTO_SSL
  if [ "$AUTO_SSL" = "y" ]; then
    read -p "Certbot e-posta adresiniz: " EMAIL
    certbot certonly --standalone -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL}
    cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /root/kohesoft/nginx_ssl/${CUSTOMER}.crt
    cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem /root/kohesoft/nginx_ssl/${CUSTOMER}.key
    chmod 600 /root/kohesoft/nginx_ssl/${CUSTOMER}.key
    SSL_BLOCK="ssl_certificate     ${CERT_PATH};\n    ssl_certificate_key ${KEY_PATH};\n    ssl_session_cache   shared:SSL:1m;\n    ssl_session_timeout 10m;\n    ssl_ciphers         HIGH:!aNULL:!MD5;\n    ssl_prefer_server_ciphers on;"
  else
    SSL_BLOCK="# SSL yok - sadece HTTP destekli"
  fi
fi

cat > "${NGINX_CONF_FILE}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
EOF

if [[ "$SSL_BLOCK" == *ssl_certificate* ]]; then
  echo "    return 301 https://\$host\$request_uri;" >> "${NGINX_CONF_FILE}"
  echo "}" >> "${NGINX_CONF_FILE}"
  echo "" >> "${NGINX_CONF_FILE}"
  echo "server {" >> "${NGINX_CONF_FILE}"
  echo "    listen 443 ssl;" >> "${NGINX_CONF_FILE}"
  echo "    server_name ${DOMAIN};" >> "${NGINX_CONF_FILE}"
  echo -e "    ${SSL_BLOCK}" >> "${NGINX_CONF_FILE}"
else
  echo "" >> "${NGINX_CONF_FILE}"
fi

cat >> "${NGINX_CONF_FILE}" <<EOF
    location / {
        proxy_pass http://wordpress_${CUSTOMER}:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "Nginx konfigürasyon dosyası oluşturuldu: ${NGINX_CONF_FILE}"

if ! docker ps --format '{{.Names}}' | grep -q "^reverse-proxy$"; then
  echo "Nginx reverse proxy container'ı başlatılıyor..."
  docker compose -f nginx_proxy/docker-compose.yml up -d
else
  docker exec reverse-proxy nginx -s reload
fi

echo "\n✅ Tüm işlemler tamamlandı. ${CUSTOMER} aktif."
echo "Cloudflare SSL ayarlarını kontrol etmeyi unutma."
