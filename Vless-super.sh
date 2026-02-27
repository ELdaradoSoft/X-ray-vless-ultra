#!/bin/bash
set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Установка Xray VLESS Reality...${NC}"

# Установка Xray если отсутствует
if ! command -v xray >/dev/null 2>&1; then
    bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
fi

apt update -y >/dev/null 2>&1
apt install -y curl openssl qrencode >/dev/null 2>&1

UUID=$(cat /proc/sys/kernel/random/uuid)
IP=$(curl -s https://api.ipify.org)

# Генерация ключей REALITY
KEYS=$(xray x25519)
PRIVATE=$(echo "$KEYS" | awk '/PrivateKey/ {print $2}')
PUBLIC=$(echo "$KEYS" | awk '/Password/ {print $2}')

if [ -z "$PRIVATE" ] || [ -z "$PUBLIC" ]; then
    echo -e "${RED}Ошибка генерации ключей!${NC}"
    exit 1
fi

SHORTID=$(openssl rand -hex 8)

# Список SNI
SNI_LIST=("www.cloudflare.com" "www.microsoft.com" "www.amazon.com" "www.google.com" "www.github.com")
SNI=${SNI_LIST[$RANDOM % ${#SNI_LIST[@]}]}

mkdir -p /usr/local/etc/xray

cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "flow": "xtls-rprx-vision"
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "dest": "www.cloudflare.com:443",
        "serverNames": ["$SNI"],
        "privateKey": "$PRIVATE",
        "shortIds": ["$SHORTID"]
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

systemctl restart xray
systemctl enable xray >/dev/null 2>&1

LINK="vless://${UUID}@${IP}:443?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC}&sid=${SHORTID}&type=tcp&flow=xtls-rprx-vision#VLESS-REALITY"

echo ""
echo -e "${GREEN}=========== ГОТОВО ===========${NC}"
echo ""

# 🔥 ЯРКО-ЖЁЛТАЯ ССЫЛКА
echo -e "${YELLOW}${LINK}${NC}"
echo ""
echo ""

qrencode -t ANSIUTF8 "$LINK"

echo ""
echo "UUID:      $UUID"
echo "PublicKey: $PUBLIC"
echo "ShortID:   $SHORTID"
echo "SNI:       $SNI"
echo "================================"
