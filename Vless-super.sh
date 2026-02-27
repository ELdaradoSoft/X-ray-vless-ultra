bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) >/dev/null 2>&1; \
apt update -y >/dev/null 2>&1; \
apt install -y curl openssl qrencode lsof >/dev/null 2>&1; \
systemctl stop xray 2>/dev/null || true; \
rm -rf /usr/local/etc/xray 2>/dev/null || true; \
if lsof -i:443 >/dev/null 2>&1; then kill -9 $(lsof -t -i:443) 2>/dev/null || true; fi; \
UUID=$(cat /proc/sys/kernel/random/uuid); \
IP=$(curl -4 -s https://api.ipify.org); \
KEYS=$(xray x25519); \
PRIVATE=$(echo "$KEYS" | grep -i private | awk '{print $2}'); \
PUBLIC=$(echo "$KEYS" | grep -Ei 'public|password' | awk '{print $2}'); \
if [ -z "$PRIVATE" ] || [ -z "$PUBLIC" ]; then echo "Ошибка генерации REALITY ключей"; exit 1; fi; \
SHORTID=$(openssl rand -hex 8); \
SNI_LIST=("www.cloudflare.com" "www.microsoft.com" "www.amazon.com" "www.google.com" "www.github.com"); \
SNI=${SNI_LIST[$RANDOM % ${#SNI_LIST[@]}]}; \
mkdir -p /usr/local/etc/xray; \
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
systemctl enable xray >/dev/null 2>&1; \
systemctl restart xray; \
LINK="vless://${UUID}@${IP}:443?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC}&sid=${SHORTID}&type=tcp&flow=xtls-rprx-vision#VLESS-REALITY"; \
echo ""; \
echo -e "\033[0;32m=========== ГОТОВО ===========\033[0m"; \
echo ""; \
echo -e "\033[1;33m$LINK\033[0m"; \
echo ""; echo ""; \
qrencode -t ANSIUTF8 "$LINK"; \
echo ""; \
echo "UUID:      $UUID"; \
echo "PublicKey: $PUBLIC"; \
echo "ShortID:   $SHORTID"; \
echo "SNI:       $SNI"; \
echo "================================"
