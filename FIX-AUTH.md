# Исправление проблемы с аутентификацией PostgreSQL

## Проблема
n8n не может подключиться к PostgreSQL с ошибкой "password authentication failed for user n8n_user"

## Причина
PostgreSQL 15 по умолчанию использует scram-sha-256 для хеширования паролей, но конфигурация была настроена на md5, что вызывало конфликт.

## Решение
Обновлена конфигурация для использования современного метода scram-sha-256:
- Добавлен `POSTGRES_HOST_AUTH_METHOD=scram-sha-256`
- Добавлен `POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256`
- Добавлен init скрипт для правильной настройки пользователя

## Инструкция по применению

### 1. На сервере перейдите в директорию N8N
```bash
cd /root/N8N
```

### 2. Получите последние изменения из git
```bash
git fetch origin main
git reset --hard origin/main
```

### 3. Остановите контейнеры и удалите старые volumes
```bash
docker compose down
docker volume rm n8n_postgres_data n8n_n8n_data
```

### 4. ВАЖНО: Проверьте ваш файл .env
Убедитесь, что в файле `/root/N8N/.env` правильно указаны все переменные:
```bash
cat .env
```

Если файл отсутствует или неполный, создайте его:
```bash
cat > .env << 'EOF'
# PostgreSQL настройки
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=ВАШ_ПАРОЛЬ_ЗДЕСЬ
POSTGRES_DB=n8n

# n8n настройки
N8N_HOST=n8n.callwith.ru
WEBHOOK_URL=https://n8n.callwith.ru/

# Базовая аутентификация (измените!)
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=ВАШ_ПАРОЛЬ_ЗДЕСЬ

# Traefik сеть
TRAEFIK_NETWORK=infra_web
EOF
```

### 5. Дайте права на выполнение init скрипту
```bash
chmod +x init-postgres.sh
```

### 6. Запустите контейнеры
```bash
docker compose up -d
```

### 7. Проверьте логи (подождите 15-20 секунд)
```bash
docker compose logs n8n --tail 50
```

Вы должны увидеть сообщение: **"n8n ready on 0.0.0.0:5678"**

### 8. Проверьте доступность n8n
```bash
# Проверьте, что n8n работает
docker compose ps

# Проверьте, что Traefik видит n8n
docker exec traefik_container_name traefik version
```

### 9. Откройте в браузере
Перейдите по адресу: https://n8n.callwith.ru

## Если проблема осталась

### Проверка 1: Посмотрите логи PostgreSQL
```bash
docker compose logs postgres --tail 50
```

### Проверка 2: Проверьте подключение вручную
```bash
docker exec n8n_postgres psql -U n8n_user -d n8n -c "SELECT version();"
```

### Проверка 3: Проверьте переменные окружения
```bash
docker exec n8n env | grep -E "(DATABASE_URL|DB_)"
docker exec n8n_postgres env | grep POSTGRES
```

### Проверка 4: Проверьте, что volumes были пересозданы
```bash
docker volume ls | grep n8n
# Дата создания должна быть свежей (сегодняшней)
docker volume inspect n8n_postgres_data | grep CreatedAt
```

## Откат к предыдущей версии
Если ничего не помогло, можно откатиться:
```bash
docker compose down
git checkout HEAD~1
docker compose up -d
```
