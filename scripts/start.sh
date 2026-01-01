#!/bin/bash
# Универсальный запуск инфраструктуры CERES (Linux/Mac)
# Поддерживает модульный запуск (выборочно) и монолитный CLEAN (fallback).

set -euo pipefail

project_name="ceres"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${script_dir}/../config"

cd "${config_dir}"

clean=false
modules=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)
      clean=true
      shift
      ;;
    *)
      modules+=("$1")
      shift
      ;;
  esac
done

if [ ! -f ".env" ]; then
  cp ".env.example" ".env"
  echo "Скопирован config/.env.example → config/.env"
  echo "Откройте config/.env и замените CHANGE_ME"
fi

gen_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import base64, os
print(base64.b64encode(os.urandom(32)).decode())
PY
  else
    # last resort; still better than CHANGE_ME
    date +%s | sha256sum | awk '{print $1}'
  fi
}

ensure_secret() {
  local key="$1"
  if grep -Eq "^${key}=CHANGE_ME\s*$" .env; then
    local val
    val="$(gen_secret)"
    # portable in-place edit (macOS needs backup suffix)
    if sed --version >/dev/null 2>&1; then
      sed -i "s/^${key}=CHANGE_ME$/${key}=${val}/" .env
    else
      sed -i '' "s/^${key}=CHANGE_ME$/${key}=${val}/" .env
    fi
    echo "Сгенерирован секрет для ${key} (значение скрыто)"
  fi
}

ensure_secret POSTGRES_PASSWORD
ensure_secret KEYCLOAK_ADMIN_PASSWORD
ensure_secret NEXTCLOUD_ADMIN_PASSWORD
ensure_secret GRAFANA_ADMIN_PASSWORD

compose_args=()

if [ "$clean" = true ]; then
  compose_args+=("-f" "docker-compose-CLEAN.yml")
else
  declare -A map=(
    [core]="compose/core.yml"
    [apps]="compose/apps.yml"
    [monitoring]="compose/monitoring.yml"
    [ops]="compose/ops.yml"
    [edge]="compose/edge.yml"
  )

  if [ ${#modules[@]} -eq 0 ]; then
    modules=(core apps monitoring ops)
  fi

  for m in "${modules[@]}"; do
    key="${m,,}"
    if [ -z "${map[$key]+x}" ]; then
      echo "Unknown module '$m'. Allowed: core, apps, monitoring, ops, edge. Or use --clean." >&2
      exit 1
    fi
    compose_args+=("-f" "${map[$key]}")
  done
fi

echo "Запуск инфраструктуры..."
docker compose --project-name "${project_name}" "${compose_args[@]}" up -d

echo "Статус контейнеров:"
docker compose --project-name "${project_name}" "${compose_args[@]}" ps

echo "Готово!"
echo "Подсказка: ./start.sh core apps  (выборочно) или ./start.sh --clean"
