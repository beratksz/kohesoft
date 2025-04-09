#!/bin/bash
# add_setup.sh
# SSL destekli olarak yeni bir müşteri ekler.
#   1) WordPress & DB container'larını oluşturur.
#   2) Müşteri için docker-compose dosyasını üretir.
#   3) Repo kökündeki ./nginx_conf dizininde müşteriye özel Nginx konfigürasyon dosyası oluşturur.
#   4) Reverse proxy container'ını kontrol eder; çalışmıyorsa başlatır, çalışıyorsa reload eder.
#   5) Ek olarak, isteğe bağlı otomatik SSL (Certbot) ile sertifika alır; istenirse manuel sertifika yüklenebilir.
#
# Reverse proxy docker-compose dosyası "nginx_proxy/docker-compose.yml" içinde absolute path kullanılarak
# host'taki /root/kohesoft/nginx_conf ve /root/kohesoft/nginx_ssl dizinleri container'a mount edilir.
#
# Her müşterinin SSL sertifika ve key dosyaları, origin sunucuda /etc/nginx/ssl altında
# görünmelidir. Örneğin, müşteri adı "kohesoft" ise; dosyalar "kohesoft.crt" ve "kohesoft.key" olarak
# kullanılacaktır.

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
echo "WordPress ve DB container'ları başlatılıyor..."
docker compose -f "${COMPOSE_FILE}" up -d

########################################
# 4. Nginx Konfigürasyon Dosyası Oluştur (SSL Dahil)
########################################
NGINX_CONF_DIR="./nginx_conf"
mkdir -p "${NGINX_CONF_DIR}"
NGINX_CONF_FILE="${NGINX_CONF_DIR}/${CUSTOMER}.conf"

cat > "${NGINX_CONF_FILE}" <<EOF
# HTTP: Tüm gelen istekleri HTTPS'e yönlendirir
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

# HTTPS: SSL sertifikası ile güvenli bağlantı, WordPress'e proxy
server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate     /etc/nginx/ssl/${CUSTOMER}.crt;
    ssl_certificate_key /etc/nginx/ssl/${CUSTOMER}.key;
    ssl_session_cache   shared:SSL:1m;
    ssl_session_timeout 10m;
    ssl_ciphers         HIGH:!aNULL:!MD5;
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
NGINX_COMPOSE_DIR="nginx_proxy"
NGINX_COMPOSE_FILE="${NGINX_COMPOSE_DIR}/docker-compose.yml"

# Eğer reverse proxy dizini yoksa oluşturup docker-compose dosyasını yazalım.
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

if ! docker ps --format '{{.Names}}' | grep -q "^reverse-proxy\$"; then
  echo "Nginx reverse proxy container'ı çalışmıyor, başlatılıyor..."
  (cd "${NGINX_COMPOSE_DIR}" && docker compose up -d)
else
  echo "Nginx reverse proxy container'ı zaten çalışıyor, konfigürasyon reload ediliyor..."
  docker exec reverse-proxy nginx -s reload
fi

########################################
# 6. SSL Sertifikası Kurulumu
########################################
# Bu adımda, otomatik SSL (Certbot) ile sertifika almak isterseniz aşağıdaki bölümü kullanabilirsiniz.
# Eğer otomatik SSL istemiyorsanız, "n" cevabı verip manuel olarak sertifika dosyalarını
# /root/kohesoft/nginx_ssl dizinine yükleyebilirsiniz.
read -p "Otomatik SSL sertifikası almak ister misiniz? (y/n): " AUTO_SSL
if [ "$AUTO_SSL" = "y" ]; then
    echo "Certbot ile SSL sertifikası alınıyor..."
    # Standalone mod kullanılıyor. Port 80/443 temporary olarak Certbot tarafından kullanılacaktır.
    # E-posta adresinizi girin:
    read -p "Certbot e-posta adresiniz: " EMAIL
    # Certbot komutunu çalıştırın; bu işlem origin sunucunuzda root (reverse proxy) üzerinde çalışacaktır.
    certbot certonly --standalone -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL}
    # Let’s Encrypt sertifikaları genellikle /etc/letsencrypt/live/${DOMAIN}/ içinde bulunur.
    # Sertifika ve anahtar dosyalarını host dizinine kopyalıyoruz.
    cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /root/kohesoft/nginx_ssl/${CUSTOMER}.crt
    cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem /root/kohesoft/nginx_ssl/${CUSTOMER}.key
    chmod 600 /root/kohesoft/nginx_ssl/${CUSTOMER}.key
    echo "Otomatik SSL sertifikası başarıyla alındı ve yüklendi."
else
    echo "Manuel SSL yüklemesi yapmak için, lütfen /root/kohesoft/nginx_ssl dizinine sertifika (örn. ${CUSTOMER}.crt) ve anahtar (örn. ${CUSTOMER}.key) dosyalarını yükleyin."
fi

# Reverse proxy container'da yapılandırma reload edelim, böylece SSL değişiklikleri aktif olsun.
docker exec reverse-proxy nginx -s reload

echo ""
echo "✅ Tüm işlemler tamamlandı."
echo "Müşteri '${CUSTOMER}' için WordPress & DB container'ları çalışıyor."
echo "Domain '${DOMAIN}', reverse proxy (SSL dahil) sayesinde yönlendirilecektir."
echo "Lütfen Cloudflare SSL/TLS ayarlarını (örneğin, 'Full (strict)') kontrol edin."
