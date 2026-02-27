#!/bin/bash
set -e

# ... (все цвета и начальные заголовки без изменений)

# Функция освобождения порта (улучшенная)
release_port() {
    local port=$1
    if lsof -i:$port >/dev/null 2>&1; then
        echo -e "${RED}  ⚠ Порт $port занят. Определяем процесс...${NC}"
        # Если это служба xray – останавливаем её корректно
        if systemctl is-active --quiet xray; then
            echo -e "${YELLOW}  ⏹ Останавливаем службу xray...${NC}"
            systemctl stop xray
            sleep 2
            if ! lsof -i:$port >/dev/null 2>&1; then
                echo -e "${GREEN}  ✓ Порт $port освобождён (служба xray остановлена)${NC}"
                return 0
            fi
        fi
        # Если не помогло – пробуем принудительно через fuser
        echo -e "${RED}  ⚠ Пробуем принудительно освободить порт $port...${NC}"
        fuser -k $port/tcp 2>/dev/null || true
        fuser -k $port/udp 2>/dev/null || true
        sleep 2
        if lsof -i:$port >/dev/null 2>&1; then
            echo -e "${RED}${BOLD}❌  Не удалось освободить порт $port. Прерывание.${NC}"
            exit 1
        else
            echo -e "${GREEN}  ✓ Порт $port освобождён${NC}"
        fi
    else
        echo -e "${GREEN}  ✓ Порт $port свободен${NC}"
    fi
}

# Далее весь код без изменений
