#!/bin/bash
set -e

echo "=========================================="
echo "N8N PostgreSQL Authentication Fix"
echo "=========================================="
echo ""

# Проверка, что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Ошибка: docker-compose.yml не найден"
    echo "Выполните: cd /root/N8N"
    exit 1
fi

echo "✓ Найден docker-compose.yml"
echo ""

# Проверка .env файла
if [ ! -f ".env" ]; then
    echo "❌ Ошибка: файл .env не найден"
    echo "Создайте файл .env на основе .env.example"
    exit 1
fi

echo "✓ Найден .env файл"
echo ""

# Показываем текущие настройки (без паролей)
echo "📋 Текущие настройки:"
echo "   POSTGRES_USER: $(grep POSTGRES_USER .env | cut -d'=' -f2)"
echo "   POSTGRES_DB: $(grep POSTGRES_DB .env | cut -d'=' -f2)"
echo "   N8N_HOST: $(grep N8N_HOST .env | cut -d'=' -f2)"
echo "   TRAEFIK_NETWORK: $(grep TRAEFIK_NETWORK .env | cut -d'=' -f2)"
echo ""

# Подтверждение
read -p "Продолжить? Все данные PostgreSQL будут удалены! (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Отменено пользователем"
    exit 0
fi
echo ""

# Остановка контейнеров
echo "🛑 Остановка контейнеров..."
docker compose down
echo "✓ Контейнеры остановлены"
echo ""

# Удаление volumes
echo "🗑️  Удаление старых volumes..."
docker volume rm n8n_postgres_data n8n_n8n_data 2>/dev/null || echo "   (volumes уже удалены или не существуют)"
echo "✓ Volumes удалены"
echo ""

# Права на скрипт
echo "🔧 Установка прав на init-postgres.sh..."
chmod +x init-postgres.sh
echo "✓ Права установлены"
echo ""

# Запуск контейнеров
echo "🚀 Запуск контейнеров с новой конфигурацией..."
docker compose up -d
echo "✓ Контейнеры запущены"
echo ""

# Ожидание инициализации
echo "⏳ Ожидание инициализации PostgreSQL (20 секунд)..."
for i in {20..1}; do
    echo -ne "   $i секунд осталось...\r"
    sleep 1
done
echo "                                  "
echo ""

# Проверка статуса
echo "📊 Статус контейнеров:"
docker compose ps
echo ""

# Проверка логов n8n
echo "📝 Последние логи n8n:"
echo "----------------------------------------"
docker compose logs n8n --tail 30
echo "----------------------------------------"
echo ""

# Проверка успешного запуска
if docker compose logs n8n --tail 50 | grep -q "n8n ready"; then
    echo "✅ УСПЕХ! n8n успешно запущен!"
    echo ""
    echo "🌐 Откройте в браузере: https://$(grep N8N_HOST .env | cut -d'=' -f2)"
    echo ""
    echo "📝 Учетные данные для входа:"
    echo "   Пользователь: $(grep N8N_BASIC_AUTH_USER .env | cut -d'=' -f2)"
    echo "   Пароль: см. N8N_BASIC_AUTH_PASSWORD в файле .env"
    echo ""
elif docker compose logs n8n --tail 50 | grep -q "password authentication failed"; then
    echo "❌ ОШИБКА: Проблема с аутентификацией PostgreSQL все еще существует"
    echo ""
    echo "🔍 Проверьте:"
    echo "1. Логи PostgreSQL: docker compose logs postgres --tail 50"
    echo "2. Переменные окружения: docker exec n8n env | grep DB_"
    echo "3. Подключение вручную: docker exec n8n_postgres psql -U n8n_user -d n8n -c 'SELECT version();'"
    echo ""
    echo "📖 Подробные инструкции по отладке в файле: FIX-AUTH.md"
else
    echo "⚠️  n8n все еще инициализируется или возникла другая проблема"
    echo ""
    echo "Подождите еще 30 секунд и проверьте логи:"
    echo "   docker compose logs n8n --tail 50"
fi
echo ""
echo "=========================================="
