#!/bin/bash
# delete_customer.sh
# Belirtilen müşterinin WordPress + DB container'larını, konfigürasyon dosyalarını
# ve isteğe bağlı olarak volume'ları sistemden kalıcı olarak siler.

set -euo pipefail

read -rp "❗ Kalıcı olarak silinecek müşteri adı (örn: musteri1): " CUSTOMER

COMPOSE_FILE="docker-compose-${CUSTOMER}.yml"
NGINX_CONF_FILE="./nginx_conf/${CUSTOMER}.conf"

echo -e "\n⚠️  Müşteri '${CUSTOMER}' silinmek üzere. İşlem geri alınamaz."

# 1. Container'ları kaldır
if [[ -f "${COMPOSE_FILE}" ]]; then
  echo "🛑 Container'lar durduruluyor ve siliniyor..."
  docker compose -f "${COMPOSE_FILE}" down --volumes
  rm -f "${COMPOSE_FILE}"
  echo "🧾 Compose dosyası silindi: ${COMPOSE_FILE}"
else
  echo "⚠️ Compose dosyası bulunamadı: ${COMPOSE_FILE}"
fi

# 2. NGINX reverse proxy konfigürasyonu
if [[ -f "${NGINX_CONF_FILE}" ]]; then
  rm -f "${NGINX_CONF_FILE}"
  echo "🧹 NGINX config silindi: ${NGINX_CONF_FILE}"
else
  echo "⚠️ NGINX config dosyası bulunamadı: ${NGINX_CONF_FILE}"
fi

# 3. İlişkili volume'ları listele ve kullanıcıya sor
echo -e "\n📦 İlişkili volume'lar:"
docker volume ls --format '{{.Name}}' | grep "${CUSTOMER}" || echo "(bulunamadı)"

read -rp "🚨 Volume'ları da silmek istiyor musunuz? (y/n): " CONFIRM
if [[ "$CONFIRM" == "y" ]]; then
  VOLUMES=$(docker volume ls --format '{{.Name}}' | grep "${CUSTOMER}" || true)
  if [[ -n "$VOLUMES" ]]; then
    echo "$VOLUMES" | xargs docker volume rm
    echo "🗑️ Volume'lar silindi."
  else
    echo "⚠️ Silinecek volume bulunamadı."
  fi
else
  echo "⏩ Volume'lar korunuyor."
fi

echo -e "\n✅ '${CUSTOMER}' tamamen silindi.\n"
