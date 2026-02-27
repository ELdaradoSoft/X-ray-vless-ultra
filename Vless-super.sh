#!/bin/bash
set -e

# 🌈 Цвета и стили
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║       УСТАНОВКА XRAY VLESS REALITY (ULTRA EDITION)        ║${NC}"
echo -e "${BOLD}${CYAN}║              с поддержкой TCP + QUIC                      ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}${BOLD}❌ Ошибка: запустите скрипт от root.${NC}"
    exit 1
fi
echo -e "${GREEN}${BOLD}✅ Права root подтверждены${NC}"

# Обновление и установка зависимостей
echo -e "${YELLOW}${BOLD}📦 Обновление пакетов и установка зависимостей...${NC}"
apt update -y > /dev/null 2>&1 && echo -e "${GREEN}  ✓ APT обновлён${NC}"
apt install -y curl openssl qrencode lsof iproute2 ufw > /dev/null 2>&1 && echo -e "${GREEN}  ✓ Утилиты установлены${NC}"

# Установка Xray
echo -e "${YELLOW}${BOLD}🚀 Установка Xray...${NC}"
bash <(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) install > /dev/null 2>&1
if ! command -v /usr/local/bin/xray &> /dev/null; then
    echo -e "${RED}${BOLD}❌ Xray не установлен. Прерывание.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Xray успешно установлен${NC}"

# Функция освобождения порта (улучшенная)
release_port() {
    local port=$1
    if lsof -i:$port >/dev/null 2>&1; then
        echo -e "${RED}  ⚠ Порт $port занят. Определяем процесс...${NC}"
        if systemctl is-active --quiet xray; then
            echo -e "${YELLOW}  ⏹ Останавливаем службу xray...${NC}"
            systemctl stop xray
            sleep 2
            if ! lsof -i:$port >/dev/null 2>&1; then
                echo -e "${GREEN}  ✓ Порт $port освобождён (служба xray остановлена)${NC}"
                return 0
            fi
        fi
        echo -e "${RED}  ⚠ Пробуем принудительно освободить порт $port...${NC}"
        fuser -k $port/tcp 2>/dev/null || true
        fuser -k $port/udp 2>/dev/null || true
        sleep 2
        if lsof -i:$port >/dev/null 2>&1; then
            echo -e "${RED}${BOLD}❌ Не удалось освободить порт $port. Прерывание.${NC}"
            exit 1
        else
            echo -e "${GREEN}  ✓ Порт $port освобождён${NC}"
        fi
    else
        echo -e "${GREEN}  ✓ Порт $port свободен${NC}"
    fi
}

# Проверка портов 443 и 8443
echo -e "${YELLOW}${BOLD}🔍 Проверка портов 443 и 8443...${NC}"
release_port 443
release_port 8443

# Генерация параметров
echo -e "${YELLOW}${BOLD}🔑 Генерация ключей и параметров...${NC}"
UUID=$(cat /proc/sys/kernel/random/uuid)
IP=$(curl -4 -s ifconfig.me || curl -s api.ipify.org)
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE=$(echo "$KEYS" | awk '/PrivateKey:/ {print $2}')
PUBLIC=$(echo "$KEYS" | awk '/Password:/ {print $2}')
if [ -z "$PRIVATE" ] || [ -z "$PUBLIC" ]; then
    echo -e "${RED}${BOLD}❌ Ошибка генерации ключей.${NC}"
    echo -e "${RED}Вывод xray x25519:${NC}"
    echo "$KEYS"
    exit 1
fi
SHORTID=$(openssl rand -hex 8)
SNI_LIST=("www.cloudflare.com" "www.microsoft.com" "www.amazon.com" "www.google.com" "www.github.com")
SNI=${SNI_LIST[$RANDOM % ${#SNI_LIST[@]}]}
echo -e "${GREEN}  ✓ UUID сгенерирован${NC}"
echo -e "${GREEN}  ✓ Ключи REALity созданы${NC}"
echo -e "${GREEN}  ✓ ShortID: ${SHORTID}${NC}"
echo -e "${GREEN}  ✓ Выбран SNI: ${SNI}${NC}"

# Создание конфигурации (TCP + QUIC)
echo -e "${YELLOW}${BOLD}⚙ Создание конфигурационного файла...${NC}"
mkdir -p /usr/local/etc/xray
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
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
    },
    {
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [{
          "id": "$UUID",
          "flow": "xtls-rprx-vision"
        }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "quic",
        "security": "reality",
        "realitySettings": {
          "dest": "$SNI:443",
          "serverNames": ["$SNI"],
          "privateKey": "$PRIVATE",
          "shortIds": ["$SHORTID"]
        }
      }
    }
  ],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF
echo -e "${GREEN}  ✓ Конфигурация сохранена${NC}"

# Валидация конфига
echo -e "${YELLOW}${BOLD}🔎 Проверка конфигурации...${NC}"
/usr/local/bin/xray validate -config /usr/local/etc/xray/config.json > /dev/null 2>&1 && echo -e "${GREEN}  ✓ Конфиг валиден${NC}"

# Открытие портов в UFW (если активен)
if command -v ufw &> /dev/null; then
    echo -e "${YELLOW}${BOLD}🔥 Настройка UFW...${NC}"
    ufw allow 443/tcp > /dev/null 2>&1 && echo -e "${GREEN}  ✓ Порт 443 (TCP) открыт${NC}"
    ufw allow 8443/udp > /dev/null 2>&1 && echo -e "${GREEN}  ✓ Порт 8443 (UDP) открыт${NC}"
    ufw reload > /dev/null 2>&1
fi

# Запуск Xray
echo -e "${YELLOW}${BOLD}▶️ Запуск Xray...${NC}"
systemctl enable xray > /dev/null 2>&1
systemctl restart xray
sleep 2
if systemctl is-active --quiet xray; then
    echo -e "${GREEN}  ✓ Xray успешно запущен${NC}"
else
    echo -e "${RED}${BOLD}❌ Xray не запустился. Журнал: journalctl -u xray${NC}"
    exit 1
fi

# Формирование ссылок
TCP_LINK="vless://${UUID}@${IP}:443?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC}&sid=${SHORTID}&type=tcp&flow=xtls-rprx-vision#VLESS-TCP"
QUIC_LINK="vless://${UUID}@${IP}:8443?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC}&sid=${SHORTID}&type=quic&flow=xtls-rprx-vision#VLESS-QUIC"

# Вывод результатов
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}                     УСТАНОВКА ЗАВЕРШЕНА                      ${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}${YELLOW}📌 Параметры подключения (общие для всех):${NC}"
echo -e "  ${BOLD}UUID:${NC}      ${UUID}"
echo -e "  ${BOLD}PublicKey:${NC} ${PUBLIC}"
echo -e "  ${BOLD}ShortID:${NC}   ${SHORTID}"
echo -e "  ${BOLD}SNI:${NC}       ${SNI}"
echo ""
echo -e "${BOLD}${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo ""

echo -e "${BOLD}${YELLOW}🔗 Ссылка VLESS + TCP (порт 443):${NC}"
echo -e "${MAGENTA}${TCP_LINK}${NC}"
echo ""
if command -v qrencode &> /dev/null; then
    echo -e "${BOLD}${YELLOW}📱 QR-код для TCP:${NC}"
    qrencode -t ANSIUTF8 "$TCP_LINK"
    echo ""
else
    echo -e "${YELLOW}⚠ qrencode не установлен, QR-код для TCP не сгенерирован.${NC}"
fi

echo -e "${BOLD}${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo ""

echo -e "${BOLD}${YELLOW}🔗 Ссылка VLESS + QUIC (порт 8443, для мобильных приложений):${NC}"
echo -e "${MAGENTA}${QUIC_LINK}${NC}"
echo ""
if command -v qrencode &> /dev/null; then
    echo -e "${BOLD}${YELLOW}📱 QR-код для QUIC:${NC}"
    qrencode -t ANSIUTF8 "$QUIC_LINK"
    echo ""
fi

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}                      ГОТОВО К РАБОТЕ!                         ${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
