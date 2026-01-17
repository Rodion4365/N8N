#!/bin/bash

# Скрипт быстрого развертывания n8n с Traefik
# Использование: ./deploy.sh

set -e

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header() {
    echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}\n"
}

# Проверка что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml не найден. Запустите скрипт из директории проекта."
    exit 1
fi

print_header "Развертывание n8n с Traefik"

# Шаг 1: Проверка Docker
print_info "Проверка установки Docker..."
if ! command -v docker &> /dev/null; then
    print_error "Docker не установлен. Установите Docker и запустите скрипт снова."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose не установлен. Установите Docker Compose и запустите скрипт снова."
    exit 1
fi

print_success "Docker $(docker --version | awk '{print $3}') установлен"
print_success "Docker Compose $(docker compose version --short) установлен"

# Шаг 2: Проверка .env файла
print_info "Проверка .env файла..."
if [ ! -f ".env" ]; then
    print_warning ".env файл не найден. Создаю из .env.example..."
    cp .env.example .env
    print_warning "ВАЖНО: Отредактируйте .env и измените пароли!"
    echo ""
    read -p "Хотите отредактировать .env сейчас? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} .env
    else
        print_error "Сначала отредактируйте .env файл и измените пароли, затем запустите скрипт снова."
        exit 1
    fi
fi

# Проверка что пароли были изменены
if grep -q "ChangeMeToSecurePassword123" .env || grep -q "ChangeThisPassword456" .env; then
    print_error "Вы не изменили пароли в .env файле!"
    echo ""
    read -p "Хотите отредактировать .env сейчас? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} .env
    else
        print_error "Измените пароли в .env файле перед развертыванием!"
        exit 1
    fi
fi

print_success ".env файл настроен"

# Шаг 3: Определение сети Traefik
print_info "Поиск сети Traefik..."
source .env

# Проверка существования указанной сети
if docker network inspect ${TRAEFIK_NETWORK} &> /dev/null; then
    print_success "Сеть Traefik найдена: ${TRAEFIK_NETWORK}"
else
    print_warning "Сеть ${TRAEFIK_NETWORK} не найдена."
    echo ""
    echo "Доступные сети Docker:"
    docker network ls
    echo ""
    read -p "Введите имя сети Traefik (например, infra_default): " network_name

    if docker network inspect ${network_name} &> /dev/null; then
        # Обновить .env файл
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/TRAEFIK_NETWORK=.*/TRAEFIK_NETWORK=${network_name}/" .env
        else
            sed -i "s/TRAEFIK_NETWORK=.*/TRAEFIK_NETWORK=${network_name}/" .env
        fi
        print_success "Сеть обновлена в .env: ${network_name}"
        TRAEFIK_NETWORK=${network_name}
    else
        print_error "Сеть ${network_name} не существует. Проверьте имя сети и запустите скрипт снова."
        exit 1
    fi
fi

# Шаг 4: Проверка DNS
print_info "Проверка DNS для ${N8N_HOST}..."
if nslookup ${N8N_HOST} &> /dev/null; then
    IP=$(nslookup ${N8N_HOST} | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    print_success "DNS настроен: ${N8N_HOST} → ${IP}"
else
    print_warning "DNS не настроен для ${N8N_HOST}"
    echo "Убедитесь что A-запись указывает на IP вашего сервера"
    echo ""
    read -p "Продолжить без DNS? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Настройте DNS и запустите скрипт снова"
        exit 1
    fi
fi

# Шаг 5: Остановка старых контейнеров (если есть)
print_info "Проверка существующих контейнеров..."
if docker ps -a | grep -q "n8n"; then
    print_warning "Найдены существующие контейнеры n8n"
    read -p "Остановить и удалить старые контейнеры? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose down
        print_success "Старые контейнеры остановлены"
    fi
fi

# Шаг 6: Запуск n8n
print_header "Запуск n8n"
print_info "Загрузка Docker образов..."
docker compose pull

print_info "Запуск контейнеров..."
docker compose up -d

# Ожидание запуска
print_info "Ожидание запуска n8n..."
sleep 5

# Проверка статуса
if docker compose ps | grep -q "n8n.*Up"; then
    print_success "n8n запущен успешно!"
else
    print_error "n8n не запустился. Проверьте логи: docker compose logs"
    exit 1
fi

# Шаг 7: Показать информацию
print_header "Развертывание завершено!"
echo ""
print_success "n8n доступен на: https://${N8N_HOST}"
echo ""
print_info "Учетные данные:"
echo "  Логин: ${N8N_BASIC_AUTH_USER}"
echo "  Пароль: ********"
echo ""
print_info "Полезные команды:"
echo "  Логи:       ./n8n-manage.sh logs"
echo "  Статус:     ./n8n-manage.sh status"
echo "  Остановить: ./n8n-manage.sh stop"
echo "  Запустить:  ./n8n-manage.sh start"
echo "  Обновить:   ./n8n-manage.sh update"
echo "  Бэкап:      ./n8n-manage.sh backup"
echo ""
print_warning "Рекомендации:"
echo "  1. Создайте первый бэкап: ./n8n-manage.sh backup"
echo "  2. Настройте регулярные бэкапы (cron)"
echo "  3. Мониторьте использование ресурсов: docker stats"
echo ""

# Показать логи
read -p "Показать логи n8n? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    print_info "Показываю логи (Ctrl+C для выхода)..."
    sleep 2
    docker compose logs -f
fi
