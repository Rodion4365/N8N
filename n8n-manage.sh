#!/bin/bash

# Скрипт управления n8n
# Использование: ./n8n-manage.sh [команда]

set -e

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

case "$1" in
    start)
        print_header "Запуск n8n"
        docker compose up -d
        print_success "n8n запущен"
        echo "Доступен на: https://n8n.callwithbot.ru"
        ;;

    stop)
        print_header "Остановка n8n"
        docker compose down
        print_success "n8n остановлен"
        ;;

    restart)
        print_header "Перезапуск n8n"
        docker compose restart
        print_success "n8n перезапущен"
        ;;

    logs)
        print_header "Логи n8n (Ctrl+C для выхода)"
        docker compose logs -f
        ;;

    status)
        print_header "Статус контейнеров"
        docker compose ps
        echo ""
        print_header "Использование ресурсов"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
        ;;

    update)
        print_header "Обновление n8n"
        print_warning "Создание бэкапа базы данных..."
        BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
        docker compose exec -T postgres pg_dump -U n8n_user n8n > "$BACKUP_FILE"
        print_success "Бэкап создан: $BACKUP_FILE"

        print_warning "Остановка контейнеров..."
        docker compose down

        print_warning "Загрузка новых образов..."
        docker compose pull

        print_warning "Запуск с новыми образами..."
        docker compose up -d

        print_success "n8n обновлен успешно!"
        ;;

    backup)
        print_header "Создание резервной копии"
        BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
        docker compose exec -T postgres pg_dump -U n8n_user n8n > "$BACKUP_FILE"
        print_success "Бэкап создан: $BACKUP_FILE"

        # Бэкап n8n data
        DATA_BACKUP="n8n_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        docker run --rm -v n8n_n8n_data:/data -v $(pwd):/backup ubuntu tar czf /backup/$DATA_BACKUP -C /data .
        print_success "Бэкап данных создан: $DATA_BACKUP"
        ;;

    restore)
        if [ -z "$2" ]; then
            print_error "Укажите файл бэкапа: ./n8n-manage.sh restore backup_YYYYMMDD_HHMMSS.sql"
            exit 1
        fi

        if [ ! -f "$2" ]; then
            print_error "Файл $2 не найден"
            exit 1
        fi

        print_header "Восстановление из бэкапа"
        print_warning "Восстановление базы данных из $2..."
        cat "$2" | docker compose exec -T postgres psql -U n8n_user -d n8n
        print_success "База данных восстановлена"

        print_warning "Перезапуск n8n..."
        docker compose restart n8n
        print_success "Восстановление завершено"
        ;;

    clean)
        print_header "Очистка неиспользуемых Docker ресурсов"
        print_warning "Это удалит неиспользуемые образы, контейнеры и volumes"
        read -p "Продолжить? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker system prune -a
            print_success "Очистка завершена"
        else
            print_warning "Отменено"
        fi
        ;;

    shell)
        print_header "Вход в контейнер n8n"
        docker compose exec n8n /bin/sh
        ;;

    psql)
        print_header "Подключение к PostgreSQL"
        docker compose exec postgres psql -U n8n_user -d n8n
        ;;

    version)
        print_header "Версия n8n"
        docker compose exec n8n n8n --version
        ;;

    help|*)
        echo "n8n Управление"
        echo ""
        echo "Использование: ./n8n-manage.sh [команда]"
        echo ""
        echo "Команды:"
        echo "  start      - Запустить n8n"
        echo "  stop       - Остановить n8n"
        echo "  restart    - Перезапустить n8n"
        echo "  logs       - Показать логи (Ctrl+C для выхода)"
        echo "  status     - Показать статус и использование ресурсов"
        echo "  update     - Обновить n8n (с автоматическим бэкапом)"
        echo "  backup     - Создать резервную копию"
        echo "  restore    - Восстановить из резервной копии"
        echo "  clean      - Очистить неиспользуемые Docker ресурсы"
        echo "  shell      - Войти в контейнер n8n"
        echo "  psql       - Подключиться к PostgreSQL"
        echo "  version    - Показать версию n8n"
        echo "  help       - Показать эту справку"
        echo ""
        echo "Примеры:"
        echo "  ./n8n-manage.sh start"
        echo "  ./n8n-manage.sh logs"
        echo "  ./n8n-manage.sh backup"
        echo "  ./n8n-manage.sh restore backup_20260117_120000.sql"
        ;;
esac
