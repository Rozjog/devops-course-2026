# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

Гипервизор: Oracle VirtualBox.
Операционная система: Ubuntu Server 24.04 LTS.
Оперативная память: 2048 МБ.
Процессор: 2 ядра.
Жёсткий диск: 25 ГБ, динамический.

## 2. Сетевые интерфейсы

Адаптер 1: NAT.
IP-адрес: 10.0.2.15.
Назначение: доступ виртуальной машины в Интернет.

Адаптер 2: Host-only.
IP-адрес: 192.168.56.101.
Назначение: связь Windows с виртуальной машиной.

Локальное имя сервера: devops.local.
Полное имя Ubuntu: devops-vm.devops.local.

В файле hosts Windows добавлена запись:
192.168.56.101 devops.local

## 3. Правило проброса портов

Сетевой адаптер: NAT.
Протокол: TCP.
Адрес хоста: 127.0.0.1.
Порт хоста: 2222.
Порт гостевой системы: 2222.

Проброс используется для SSH-подключения
к виртуальной машине.

## 4. Учётные записи

student — пользователь, созданный при установке Ubuntu.

devops — пользователь для удалённого администрирования.

Группы пользователя devops: sudo, docker.

SSH-аутентификация выполняется по ключу ED25519.
Закрытый ключ хранится на клиенте в ~/.ssh/devops_vm.
Публичный ключ размещён на сервере в
/home/devops/.ssh/authorized_keys.

Вход по паролю через SSH отключён.

## 5. Служба SSH

Установлен OpenSSH Server.

Порт SSH: 2222.

Основной файл дополнительной конфигурации:
/etc/ssh/sshd_config.d/99-hardening.conf

Настроенные параметры:

Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2

Служба ssh.socket отключена.
Служба ssh.service включена.

Проверка конфигурации:
sudo sshd -t
sudo sshd -T
sudo ss -tlnp | grep sshd

## 6. Межсетевой экран

Используется UFW.

Политики по умолчанию:
deny incoming
allow outgoing

Разрешённые порты:
2222/tcp — SSH, правило LIMIT.
80/tcp — HTTP.
443/tcp — HTTPS.

Команда проверки:
sudo ufw status verbose

Входящие подключения на остальные порты
по умолчанию запрещены.

## 7. Снимки состояния

01-clean-install — после установки Ubuntu.
02-keys-configured — после настройки SSH-ключей.
03-ssh-hardened — после защиты SSH.
04-nginx-https — после настройки HTTPS.
05-docker-compose — после настройки Docker Compose.

## 8. Веб-сервер

Установлен Nginx.

Конфигурация сайта:
/etc/nginx/sites-available/devops-site

Активная ссылка:
/etc/nginx/sites-enabled/devops-site

Каталог сайта:
/var/www/devops-site

Владелец: devops.
Права каталогов: 755.
Права файлов: 644.

Самоподписанный TLS-сертификат:
/etc/ssl/certs/devops.crt

Закрытый ключ:
/etc/ssl/private/devops.key

Права сертификата: 644.
Права закрытого ключа: 600.

Сертификат создан через OpenSSL
для доменного имени devops.local
со сроком действия 365 дней.

HTTP (порт 80) перенаправляется на HTTPS (порт 443).

Сайт доступен по адресу:
https://devops.local/

Проверка конфигурации:
sudo nginx -t

Применение изменений:
sudo systemctl reload nginx

## 9. Контейнеризация

Docker Engine установлен на Ubuntu Server 24.04
из официального репозитория Docker.

Версия Docker Engine: 29.9.1.
Установлен плагин Docker Compose.

Пользователь devops входит в группу docker
и запускает контейнеры без sudo.

Каталог проекта на сервере:
/home/devops/app

Образ приложения:
devops-app:1.0

Приложение написано на Python с использованием Flask.
Для запуска используется Gunicorn.
В контейнере приложение работает от пользователя app,
а не root.

Файл конфигурации Docker Compose:
/home/devops/app/docker-compose.yml

Сервисы:
app — Flask-приложение.
db — PostgreSQL 16-alpine.

Сервисы взаимодействуют через сеть app_backend.
Приложение находит базу данных по имени db.

Данные PostgreSQL хранятся в именованном
томе app_db_data.

Файл переменных окружения:
/home/devops/app/.env

Права файла .env: 600.

Файл содержит секреты и хранится только на сервере.
Его содержимое не добавляется в Git.

Порт приложения опубликован на адресе:
127.0.0.1:5000

Порт PostgreSQL 5432 наружу не публикуется.

Nginx работает как обратный прокси.

Адрес:
https://devops.local/app/

перенаправляется на:
http://127.0.0.1:5000/

Для этого используется директива:
proxy_pass http://127.0.0.1:5000/;

Статический сайт https://devops.local/
сохраняется.

Команды проверки:
docker version
docker compose version
docker compose ps
docker network ls
sudo ss -tlnp
