#!/bin/bash
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}=== Установка Xray VLESS Reality (с поддержкой QR) ===${NC}"

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Запустите от root.${NC}"
    exit 1
fi

# Установка зависимостей (включая qrencode)
apt update -y
apt install -y curl openssl qrencode lsof iproute2

# Установка Xray
echo -e "${YELLOW}Устанавливаем Xray...${NC}"
bash <(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) install

# Освобождение порта 443
if lsof -i:443 >/dev/null 2>&1; then
    echo -e "${YELLOW}Освобождаем порт 443...${NC}"
    fuser -k 443/tcp 2>/dev/null || true
    sleep 1
fi

# Генерация параметров
UUID=$(cat /proc/sys/kernel/random/uuid)
IP=$(curl -4 -s ifconfig.me || curl -s api.ipify.org)
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE=$(echo "$KEYS" | awk '/PrivateKey:/ {print $2}')
PUBLIC=$(echo "$KEYS" | awk '/Password:/ {print $2}')
if [ -z "$PRIVATE" ] || [ -z "$PUBLIC" ]; then
    echo -e "${RED}Ошибка генерации ключей. Вывод xray x25519:${NC}"
    echo "$KEYS"
    exit 1
fi
SHORTID=$(openssl rand -hex 8)
SNI_LIST=("www.cloudflare.com" "www.microsoft.com" "www.amazon.com" "www.google.com" "www.github.com")
SNI=${SNI_LIST[$RANDOM % ${#SNI_LIST[@]}]}

# Создание конфига
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
        "dest": "$SNI:443",
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

# Валидация конфига
echo -e "${YELLOW}Проверяем конфиг...${NC}"
/usr/local/bin/xray validate -config /usr/local/etc/xray/config.json

# Запуск Xray
systemctl enable xray
systemctl restart xray
sleep 2

if systemctl is-active --quiet xray; then
    echo -e "${GREEN}Xray успешно запущен.${NC}"
else
    echo -e "${RED}Xray не запустился. Журнал: journalctl -u xray${NC}"
    exit 1
fi

# Формирование ссылки
LINK="vless://${UUID}@${IP}:443?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC}&sid=${SHORTID}&type=tcp&flow=xtls-rprx-vision#VLESS-REALITY"

# Вывод результатов
echo ""
echo -e "${GREEN}=========== ГОТОВО ===========${NC}"
echo ""
echo -e "${YELLOW}$LINK${NC}"
echo ""
echo "UUID:      $UUID"
echo "PublicKey: $PUBLIC"
echo "ShortID:   $SHORTID"
echo "SNI:       $SNI"
echo ""

# Генерация QR-кода
if command -v qrencode &> /dev/null; then
    echo -e "${GREEN}QR-код для подключения:${NC}"
    qrencode -t ANSIUTF8 "$LINK"
else
    echo -e "${YELLOW}qrencode не установлен, QR-код не сгенерирован.${NC}"
fi

echo -e "${GREEN}================================${NC}"

