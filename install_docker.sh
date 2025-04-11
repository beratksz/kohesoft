#!/bin/bash
set -euo pipefail

echo "🔧 Sistem güncelleniyor..."
sudo apt update -y
sudo apt upgrade -y

echo "🐳 Docker resmi reposu ekleniyor..."
sudo apt install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔄 Paket listesi yenileniyor..."
sudo apt update -y

echo "📦 Docker ve Compose plugin kuruluyor..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "👤 Kullanıcı Docker grubuna ekleniyor..."
sudo usermod -aG docker "$USER"

echo "✅ Docker kuruldu!"
docker --version
docker compose version

echo -e "\n📌 Not: Değişikliklerin etkili olması için oturumu kapatıp açman ya da şu komutu girmen gerekir:"
echo "    newgrp docker"
