# Инструкция по установке n8n на сервере

## 📋 Требования

- Ubuntu 22.04 LTS
- Docker и Docker Compose
- Nginx
- Доступ к DNS для настройки домена n8n.callwithbot.ru

## 🚀 Шаг 1: Установка Docker и Docker Compose

```bash
# Обновить систему
sudo apt update && sudo apt upgrade -y

# Установить необходимые пакеты
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Добавить официальный GPG ключ Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Добавить репозиторий Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установить Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Добавить пользователя в группу docker (чтобы не использовать sudo)
sudo usermod -aG docker $USER

# Перелогиниться или выполнить:
newgrp docker

# Проверить установку
docker --version
docker compose version
```

## 🔧 Шаг 2: Настройка DNS

Добавьте A-запись для поддомена:
```
A Record: n8n.callwithbot.ru -> [IP вашего сервера]
```

Дождитесь распространения DNS (проверить можно командой):
```bash
nslookup n8n.callwithbot.ru
```

## 🔐 Шаг 3: Настройка переменных окружения

```bash
# Перейти в директорию проекта
cd /home/user/N8N

# Отредактировать .env файл и изменить пароли!
nano .env
```

**ВАЖНО:** Измените следующие значения:
- `POSTGRES_PASSWORD` - надежный пароль для базы данных
- `N8N_BASIC_AUTH_USER` - имя пользователя для входа в n8n
- `N8N_BASIC_AUTH_PASSWORD` - надежный пароль для входа в n8n

## 🚢 Шаг 4: Запуск n8n

```bash
# Запустить n8n в фоновом режиме
docker compose up -d

# Проверить статус контейнеров
docker compose ps

# Посмотреть логи
docker compose logs -f

# Остановить (если нужно)
docker compose down
```

## 🌐 Шаг 5: Настройка Nginx и SSL

### 5.1 Установка Nginx и Certbot

```bash
# Установить Nginx
sudo apt install -y nginx

# Установить Certbot для Let's Encrypt
sudo apt install -y certbot python3-certbot-nginx

# Создать директорию для certbot challenge
sudo mkdir -p /var/www/certbot
```

### 5.2 Настройка Nginx

```bash
# Скопировать конфигурацию
sudo cp nginx-n8n.conf /etc/nginx/sites-available/n8n.callwithbot.ru

# Временно закомментировать SSL строки (так как сертификата еще нет)
sudo nano /etc/nginx/sites-available/n8n.callwithbot.ru
# Закомментируйте строки с ssl_certificate (добавьте # в начале)

# Создать симлинк
sudo ln -s /etc/nginx/sites-available/n8n.callwithbot.ru /etc/nginx/sites-enabled/

# Проверить конфигурацию
sudo nginx -t

# Перезапустить Nginx
sudo systemctl restart nginx
```

### 5.3 Получение SSL сертификата

```bash
# Получить сертификат от Let's Encrypt
sudo certbot --nginx -d n8n.callwithbot.ru

# Следуйте инструкциям:
# - Введите email
# - Согласитесь с условиями
# - Certbot автоматически настроит SSL

# Проверить автообновление сертификата
sudo certbot renew --dry-run
```

### 5.4 Финальная настройка Nginx

```bash
# Раскомментировать SSL строки в конфигурации
sudo nano /etc/nginx/sites-available/n8n.callwithbot.ru
# Уберите # перед строками ssl_certificate

# Проверить конфигурацию
sudo nginx -t

# Перезапустить Nginx
sudo systemctl restart nginx
```

## ✅ Шаг 6: Проверка работы

1. Откройте браузер и перейдите на: https://n8n.callwithbot.ru
2. Введите логин и пароль из `.env` файла
3. Вы должны увидеть интерфейс n8n!

## 📊 Мониторинг ресурсов

```bash
# Проверить использование ресурсов контейнерами
docker stats

# Посмотреть логи n8n
docker compose logs -f n8n

# Посмотреть логи PostgreSQL
docker compose logs -f postgres
```

### Текущие ограничения ресурсов:

- **PostgreSQL**: макс. 384MB RAM, 50% CPU
- **n8n**: макс. 768MB RAM, 100% CPU (1 ядро)
- **Итого**: ~1.15GB RAM максимум

Это оставляет ~2.85GB для других проектов на вашем сервере.

## 🔄 Обновление n8n

```bash
# Остановить контейнеры
docker compose down

# Обновить образы
docker compose pull

# Запустить с новыми образами
docker compose up -d

# Проверить логи
docker compose logs -f
```

## 🗄️ Резервное копирование

```bash
# Создать бэкап PostgreSQL
docker compose exec postgres pg_dump -U n8n_user n8n > backup_$(date +%Y%m%d_%H%M%S).sql

# Восстановить из бэкапа
cat backup_YYYYMMDD_HHMMSS.sql | docker compose exec -T postgres psql -U n8n_user -d n8n

# Бэкап volumes
docker run --rm -v n8n_n8n_data:/data -v $(pwd):/backup ubuntu tar czf /backup/n8n_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
```

## 🔧 Увеличение ресурсов (при необходимости)

Если в будущем понадобится больше ресурсов, отредактируйте `docker-compose.yml`:

```yaml
# Для n8n
deploy:
  resources:
    limits:
      memory: 1536M    # Увеличить до 1.5GB
      cpus: '1.5'      # Увеличить до 1.5 ядер
```

После изменений:
```bash
docker compose down
docker compose up -d
```

## 🆘 Решение проблем

### n8n не запускается

```bash
# Проверить логи
docker compose logs n8n

# Проверить здоровье PostgreSQL
docker compose exec postgres pg_isready -U n8n_user
```

### Ошибки памяти

```bash
# Проверить использование памяти
docker stats

# Уменьшить лимиты в docker-compose.yml
# Или увеличить swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### SSL не работает

```bash
# Проверить статус Certbot
sudo certbot certificates

# Обновить сертификаты вручную
sudo certbot renew --force-renewal

# Проверить Nginx
sudo nginx -t
sudo systemctl status nginx
```

## 📞 Полезные команды

```bash
# Перезапустить n8n
docker compose restart n8n

# Посмотреть все контейнеры
docker ps -a

# Очистить неиспользуемые ресурсы Docker
docker system prune -a

# Проверить версию n8n
docker compose exec n8n n8n --version
```

## 🔒 Безопасность

1. ✅ Используйте сильные пароли в `.env`
2. ✅ Регулярно обновляйте n8n: `docker compose pull && docker compose up -d`
3. ✅ Делайте резервные копии базы данных
4. ✅ Настройте firewall (ufw):
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 22/tcp
   sudo ufw enable
   ```
5. ✅ Мониторьте логи: `docker compose logs -f`

## 📚 Дополнительные ресурсы

- [Официальная документация n8n](https://docs.n8n.io)
- [n8n Community Forum](https://community.n8n.io)
- [Docker Compose документация](https://docs.docker.com/compose/)

---

**Примечание:** После установки не забудьте изменить пароли в `.env` файле!
