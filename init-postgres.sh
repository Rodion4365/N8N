#!/bin/bash
set -e

# Этот скрипт выполняется при первой инициализации PostgreSQL

echo "Creating user and database with proper authentication..."

# Создаем пользователя и базу данных, если они не существуют
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Настраиваем пароль с правильным методом хеширования
    ALTER USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';
EOSQL

echo "PostgreSQL initialization complete!"
