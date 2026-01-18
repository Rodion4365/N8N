#!/bin/bash

echo "=========================================="
echo "PostgreSQL Authentication Debug"
echo "=========================================="
echo ""

echo "1. Проверка переменных окружения в .env файле:"
echo "----------------------------------------"
cat .env | grep -E "(POSTGRES_USER|POSTGRES_PASSWORD|POSTGRES_DB)" | sed 's/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=**********/'
echo ""

echo "2. Проверка переменных в контейнере PostgreSQL:"
echo "----------------------------------------"
docker exec n8n_postgres env | grep POSTGRES | sed 's/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=**********/'
echo ""

echo "3. Проверка переменных в контейнере n8n:"
echo "----------------------------------------"
docker exec n8n env | grep -E "(DATABASE_URL|DB_POSTGRESDB)" | sed 's/PASSWORD=.*/PASSWORD=**********/' | sed 's/:.*@/:***@/'
echo ""

echo "4. Проверка pg_hba.conf:"
echo "----------------------------------------"
docker exec n8n_postgres cat /var/lib/postgresql/data/pg_hba.conf 2>/dev/null | grep -v "^#" | grep -v "^$"
echo ""

echo "5. Проверка версии PostgreSQL:"
echo "----------------------------------------"
docker exec n8n_postgres psql --version
echo ""

echo "6. Тест подключения с localhost (должен работать):"
echo "----------------------------------------"
docker exec n8n_postgres psql -h localhost -U n8n_user -d n8n -c "SELECT 'SUCCESS' as status, version();" 2>&1 | head -5
echo ""

echo "7. Проверка метода хеширования пароля пользователя:"
echo "----------------------------------------"
docker exec n8n_postgres psql -U postgres -d n8n -c "SELECT usename, usesuper, passwd IS NOT NULL as has_password FROM pg_shadow WHERE usename = 'n8n_user';" 2>&1 || \
docker exec n8n_postgres psql -U n8n_user -d n8n -c "SELECT current_user, current_database();" 2>&1
echo ""

echo "8. Полные логи PostgreSQL (последние 30 строк):"
echo "----------------------------------------"
docker compose logs postgres --tail 30 2>&1 | grep -v "WARN"
echo ""

echo "9. Полные логи n8n (последние 20 строк):"
echo "----------------------------------------"
docker compose logs n8n --tail 20 2>&1 | grep -v "WARN"
echo ""

echo "=========================================="
echo "Анализ завершен"
echo "=========================================="
