#!/bin/bash
# add_customer.sh
# SSL destekli olarak yeni bir müşteri ekler:
#   1) WP & DB container'larını oluşturur.
#   2) Müşteriye özel docker-compose dosyasını üretir.
#   3) Repo kökü altındaki ./nginx_conf dizininde, HTTP->HTTPS yönlendirme ve HTTPS sunumuyla
#      müşteriye özel Nginx konfigürasyon dosyası oluşturur.
#   4) Reverse proxy container'ını kontrol eder; çalışmıyorsa başlatır, çalışıyorsa konfig reload eder.
#
# Reverse proxy docker-compose dosyası "nginx_proxy/docker-compose.yml" içinde,
# absolute path kullanılarak host'taki nginx_conf ve nginx_ssl dizinleri container'a mount edilir.
#
# SSL: Her müşteri için /root/kohesoft/nginx_ssl dizininde, örneğin:
#    - /root/kohesoft/nginx_ssl/<CUSTOMER>.crt
#    - /root/kohesoft/nginx_ssl/<CUSTOMER>.key
# dosyaları bulunmalı.

set -e

########################################
# 1. Docker Network Kontrolü
########################################
NETWORK_NAME="wp_network"
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}\$"; then
  echo "Docker network '${NETWORK_NAME}' bulunamadı. Oluşturuluyor..."
  docker network create ${NETWORK_NAME}
else
  echo "Docker network '${NETWORK_NAME}' zaten mevcut."
fi

########################################
# 2. Müşteri Bilgilerini Al
########################################
read -p "Müşteri adını girin (örn: musteri1): " CUSTOMER
read -p "Port son ekini girin (örn: 01,02 vs.): " PORT_SUFFIX
read -p "Domain ismini girin (örn: musteri1.com): " DOMAIN

# Veritabanı ayarları
WP_DB_NAME="wp_db_${CUSTOMER}"
WP_DB_USER="wp_user_${CUSTOMER}"
WP_DB_PASS="wp_pass_${CUSTOMER}"
ROOT_PASS="root_pass_${CUSTOMER}"

########################################
# 3. Docker Compose Dosyasını Oluştur (WP & DB)
########################################
COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"

cat > "${COMPOSE_FILE}" <<EOF
version: '3.8'
services:
  wordpress_${CUSTOMER}:
    image: wordpress:latest
    container_name: wordpress_${CUSTOMER}
    restart: always
    ports:
      - "80${PORT_SUFFIX}:80"   # Örnek: 8001, 8002 gibi.
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
echo "WordPress ve DB container'ları başlatılıyor..."
docker compose -f "${COMPOSE_FILE}" up -d

########################################
# 4. Nginx Konfigürasyon Dosyası Oluştur (SSL Dahil)
########################################
# Konfigürasyon dosyaları repo kökünde "nginx_conf" dizininde tutulur.
NGINX_CONF_DIR="./nginx_conf"
mkdir -p "${NGINX_CONF_DIR}"
NGINX_CONF_FILE="${NGINX_CONF_DIR}/${CUSTOMER}.conf"

cat > "${NGINX_CONF_FILE}" <<EOF
# HTTP: Gelen tüm istekleri HTTPS'e yönlendirir
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

# HTTPS: SSL sertifikalarıyla korumalı bağlantı ve WordPress proxy
server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate     /etc/nginx/ssl/${CUSTOMER}.crt;
    ssl_certificate_key /etc/nginx/ssl/${CUSTOMER}.key;
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 10m;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://wordpress_${CUSTOMER}:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "Nginx konfigürasyon dosyası oluşturuldu: ${NGINX_CONF_FILE}"

########################################
# 5. Reverse Proxy Container'ını Kontrol ve Yönet (SSL Dahil)
########################################
# Reverse proxy için docker-compose dosyası "nginx_proxy/docker-compose.yml" altında.
NGINX_COMPOSE_DIR="nginx_proxy"
NGINX_COMPOSE_FILE="${NGINX_COMPOSE_DIR}/docker-compose.yml"

# Eğer reverse proxy dizini yoksa oluştur ve docker-compose dosyasını yaz.
if [ ! -d "${NGINX_COMPOSE_DIR}" ]; then
  echo "nginx_proxy dizini bulunamadı, oluşturuluyor..."
  mkdir -p "${NGINX_COMPOSE_DIR}"
  cat > "${NGINX_COMPOSE_FILE}" <<'EOF'
version: "3.8"
services:
  reverse-proxy:
    image: nginx:latest
    container_name: reverse-proxy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /root/kohesoft/nginx_conf:/etc/nginx/conf.d:ro
      - /root/kohesoft/nginx_ssl:/etc/nginx/ssl:ro
    networks:
      - wp_network

networks:
  wp_network:
    external: true
EOF
  echo "Nginx reverse proxy docker-compose dosyası oluşturuldu: ${NGINX_COMPOSE_FILE}"
fi

# Reverse proxy container'ının çalışıp çalışmadığını kontrol edelim.
if ! docker ps --format '{{.Names}}' | grep -q "^reverse-proxy\$"; then
  echo "Nginx reverse proxy container'ı çalışmıyor, başlatılıyor..."
  (cd "${NGINX_COMPOSE_DIR}" && docker compose up -d)
else
  echo "Nginx reverse proxy container'ı zaten çalışıyor, konfigürasyon reload ediliyor..."
  docker exec reverse-proxy nginx -s reload
fi

echo ""
echo "✅ Tüm işlemler tamamlandı."
echo "Müşteri '${CUSTOMER}' için WordPress & DB container'ları çalışıyor."
echo "Domain '${DOMAIN}' reverse proxy (SSL dahil) sayesinde yönlendirilecektir."
echo "Not: Cloudflare SSL ayarlarını, 'Full' ya da 'Full (strict)' modunda yapılandırdığınızdan emin olun."
