#!/bin/bash
read -p "Silinecek müşteri adı: " CUSTOMER

docker compose -f docker-compose-${CUSTOMER}.yml down -v

rm -f docker-compose-${CUSTOMER}.yml ./nginx_conf/${CUSTOMER}.conf
docker exec reverse-proxy nginx -s reload

echo "🗑️ Müşteri '${CUSTOMER}' kalıcı olarak silindi."
