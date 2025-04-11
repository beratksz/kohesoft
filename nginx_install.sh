#!/bin/bash
# nginx-proxy ve Let's Encrypt companion için tam kurulum scripti
# Ayrıca SSL için dhparam.pem üretir ve mount ayarlarını yapar

set -euo pipefail

echo "🔧 Gerekli klasörler oluşturuluyor..."
mkdir -p ./nginx/conf.d ./nginx/vhost.d ./nginx/html ./nginx/certs ./nginx/dhparam

if [ ! -f ./nginx/dhparam/dhparam.pem ]; then
  echo "🔐 dhparam.pem dosyası oluşturuluyor (bu birkaç dakika sürebilir)..."
  openssl dhparam -out ./nginx/dhparam/dhparam.pem 2048
else
  echo "✅ dhparam.pem zaten mevcut."
fi

echo "📄 docker-compose.yml dosyası yazılıyor..."

cat > docker-compose.yml <<EOF
version: "3.8"

services:
  nginx-proxy:
    image: jwilder/nginx-proxy:latest
    container_name: nginx-proxy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/vhost.d:/etc/nginx/vhost.d
      - ./nginx/html:/usr/share/nginx/html
      - ./nginx/certs:/etc/nginx/certs
      - ./nginx/dhparam:/etc/nginx/dhparam:ro
    networks:
      - wp_network

  letsencrypt:
    image: jrcs/letsencrypt-nginx-proxy-companion
    container_name: letsencrypt
    restart: always
    depends_on:
      - nginx-proxy
    environment:
      - NGINX_PROXY_CONTAINER=nginx-proxy
      - DEFAULT_EMAIL=admin@kohesoft.com
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./nginx/certs:/etc/nginx/certs
      - ./nginx/vhost.d:/etc/nginx/vhost.d
      - ./nginx/html:/usr/share/nginx/html
    networks:
      - wp_network

networks:
  wp_network:
    external: true
EOF

echo "🚀 nginx-proxy ve Let's Encrypt container'ları başlatılıyor..."
docker compose up -d

echo -e "\n✅ Tüm kurulum tamamlandı. Artık güvenli SSL sertifikalarıyla müşteri ekleyebilirsin. 💪"
