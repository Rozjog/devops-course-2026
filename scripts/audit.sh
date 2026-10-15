
#!/usr/bin/env bash

set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo " [OK] $desc"
        ((PASS += 1))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL += 1))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

# Практическая работа №5

echo "[1] Служба SSH"

SSH_CONFIG="$(sudo sshd -T 2>/dev/null)"

check "Вход root запрещён" "no" \
    "$(echo "$SSH_CONFIG" | awk '/^permitrootlogin / {print $2}')"

check "Парольная аутентификация отключена" "no" \
    "$(echo "$SSH_CONFIG" | awk '/^passwordauthentication / {print $2}')"

SSH_PORT="$(echo "$SSH_CONFIG" | awk '/^port / {print $2; exit}')"

if [[ -n "$SSH_PORT" && "$SSH_PORT" != "22" ]]; then
    PORT_RESULT="yes"
else
    PORT_RESULT="no"
fi

check "Порт SSH отличается от 22" "yes" "$PORT_RESULT"

check "MaxAuthTries равен 3" "3" \
    "$(echo "$SSH_CONFIG" | awk '/^maxauthtries / {print $2}')"

echo "[2] Межсетевой экран"

check "UFW активен" "active" \
    "$(sudo ufw status | awk '/^Status:/ {print $2}')"

UFW_INCOMING="$(sudo ufw status verbose | \
    sed -n 's/^Default: \([^ ]*\) (incoming).*/\1/p')"

check "Входящий трафик по умолчанию запрещён" \
    "deny" "$UFW_INCOMING"

echo "[3] Учётные записи"

awk -F: '$3 >= 1000 && $3 < 65534 {
    printf " %s (uid=%s)\n", $1, $3
}' /etc/passwd

# Практическая работа №6

echo "[4] Веб-сервер"

check "Nginx активен" "active" \
    "$(systemctl is-active nginx 2>/dev/null || true)"

NGINX_RESULT="error"

if sudo nginx -t >/dev/null 2>&1; then
    NGINX_RESULT="ok"
fi

check "Конфигурация Nginx корректна" "ok" "$NGINX_RESULT"

CERT_RESULT="error"

if openssl x509 \
    -in /etc/ssl/certs/devops.crt \
    -checkend 2592000 -noout >/dev/null 2>&1; then
    CERT_RESULT="ok"
fi

check "Сертификат действителен ещё 30 дней" \
    "ok" "$CERT_RESULT"

KEY_RIGHTS="$(sudo stat -c '%a' \
    /etc/ssl/private/devops.key 2>/dev/null || true)"

WEB_RIGHTS="error"

if [[ -d /var/www/devops-site ]]; then
    UNSAFE_FILES="$(find /var/www/devops-site -perm -o+w -print)"

    if [[ -z "$UNSAFE_FILES" && "$KEY_RIGHTS" == "600" ]]; then
        WEB_RIGHTS="ok"
    fi
fi

check "Права файлов сайта и TLS-ключа безопасны" \
    "ok" "$WEB_RIGHTS"

# Практическая работа №7

echo "[5] Контейнеризация"

check "Docker активен" "active" \
    "$(systemctl is-active docker 2>/dev/null || true)"

DB_STATUS="$(docker inspect -f '{{.State.Health.Status}}' \
    app-db-1 2>/dev/null || true)"

check "PostgreSQL находится в состоянии healthy" \
    "healthy" "$DB_STATUS"

UNSAFE_PORTS="$(ss -H -tln | awk '
    $4 ~ /:(5000|5432)$/ &&
    $4 !~ /^127\.0\.0\.1:(5000|5432)$/ {
        print $4
    }
')"

PORT_STATUS="ok"

if [[ -n "$UNSAFE_PORTS" ]]; then
    PORT_STATUS="$UNSAFE_PORTS"
fi

check "Порты 5000 и 5432 не открыты наружу" \
    "ok" "$PORT_STATUS"

ENV_RIGHTS="$(stat -c '%a' "$HOME/app/.env" 2>/dev/null || true)"

check "Права файла .env равны 600" "600" "$ENV_RIGHTS"

echo "Пройдено: $PASS, не пройдено: $FAIL"

if [[ "$FAIL" -eq 0 ]]; then
    exit 0
else
    exit 1
fi
