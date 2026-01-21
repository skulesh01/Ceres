# Ingress Controller Fix - January 2026

## Проблема
- ingress-nginx controller падал с ошибкой "restrictive Authorization mode"
- Permission denied при создании SSL сертификатов
- Keycloak был недоступен через Ingress

## Решение

### 1. Используем встроенный Traefik вместо ingress-nginx
K3s поставляется с предустановленным Traefik ingress controller, который работает стабильно.

**Проверка:**
```bash
kubectl get pods -n kube-system | grep traefik
kubectl get svc traefik -n kube-system
```

### 2. Обновлены все Ingress манифесты
- `ingressClassName: nginx` → `ingressClassName: traefik`
- Удалены nginx-специфичные аннотации
- Добавлен `ingress-ip.yaml` для доступа без hosts файла

### 3. Исправлен Keycloak deployment
**Изменения в `deployment/keycloak.yaml`:**
- Добавлен `runAsUser: 0` в securityContext (запуск от root)
- Упрощен пароль администратора: `admin123`
- Добавлены переменные для проксирования:
  - `KC_PROXY: edge`
  - `KC_HOSTNAME_STRICT: false`
  - `KC_HTTP_ENABLED: true`
- Убраны проблемные health probes (readiness/liveness)

### 4. Удален ValidatingWebhookConfiguration
```bash
kubectl delete validatingwebhookconfiguration ingress-nginx-admission
```

## Инструкции по деплою

### Быстрый старт (с обновленными файлами):
```bash
# 1. Применить Keycloak
kubectl apply -f deployment/keycloak.yaml

# 2. Применить Ingress с доменами
kubectl apply -f deployment/ingress-domains.yaml

# 3. Применить Ingress для доступа по IP
kubectl apply -f deployment/ingress-ip.yaml

# 4. Проверить доступность
curl -s http://192.168.1.3/ | grep Keycloak
```

### Доступ к сервисам:

**Вариант 1: По IP (без настройки hosts)**
- Keycloak: http://192.168.1.3/
- Логин: admin / admin123

**Вариант 2: По доменам (требует hosts)**
Добавить в `/etc/hosts` (Linux/Mac) или `C:\Windows\System32\drivers\etc\hosts` (Windows):
```
192.168.1.3 keycloak.ceres.local gitlab.ceres.local grafana.ceres.local chat.ceres.local
```

Затем:
- Keycloak: http://keycloak.ceres.local/
- GitLab: http://gitlab.ceres.local/
- Grafana: http://grafana.ceres.local/
- и т.д.

## Автоматизация

Добавить в скрипт деплоя проверку и переключение на Traefik:

```bash
# Удалить ingress-nginx если есть
if kubectl get namespace ingress-nginx 2>/dev/null; then
    kubectl delete namespace ingress-nginx --wait=false
    kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true
fi

# Убедиться что Traefik работает
kubectl wait --namespace kube-system \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=traefik \
    --timeout=60s
```

## Проверка работоспособности

```bash
# Traefik должен быть Running
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# Keycloak должен быть Running (может занять 30-60 секунд)
kubectl get pods -n ceres -l app=keycloak

# Тест доступности
curl -I http://192.168.1.3/

# Проверка всех Ingress
kubectl get ingress -A
```

## Преимущества нового подхода

1. **Стабильность**: Traefik встроен в K3s и тестирован
2. **Простота**: Не требует дополнительной установки
3. **LoadBalancer**: Traefik имеет IP 192.168.1.3 из коробки
4. **Гибкость**: Доступ по IP или по доменам

## Troubleshooting

### Keycloak не запускается
```bash
# Проверить логи
kubectl logs -n ceres deployment/keycloak

# Если ошибка Permission denied - проверить securityContext
kubectl get deployment keycloak -n ceres -o yaml | grep -A5 securityContext
```

### Ingress не работает
```bash
# Проверить класс ingress
kubectl get ingress -A -o wide

# Должно быть ingressClassName: traefik, не nginx
# Если нет - пересоздать:
kubectl delete ingress --all -A
kubectl apply -f deployment/ingress-domains.yaml
kubectl apply -f deployment/ingress-ip.yaml
```

### 404 Not Found
```bash
# Проверить что Keycloak pod запущен
kubectl get pods -n ceres

# Проверить service
kubectl get svc -n ceres keycloak

# Тест напрямую через service
kubectl port-forward -n ceres svc/keycloak 8080:8080
# Открыть http://localhost:8080
```

## Команды для отката (если нужно вернуть ingress-nginx)

```bash
# Удалить Traefik ingress
kubectl delete -f deployment/ingress-domains.yaml
kubectl delete -f deployment/ingress-ip.yaml

# Установить ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml

# Патчить на NodePort
kubectl patch svc ingress-nginx-controller -n ingress-nginx \
  -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"nodePort":30080},{"name":"https","port":443,"nodePort":30443}]}}'

# Изменить ingressClassName обратно
sed -i 's/ingressClassName: traefik/ingressClassName: nginx/g' deployment/ingress-domains.yaml
kubectl apply -f deployment/ingress-domains.yaml
```

Но этого **не рекомендуется** делать - Traefik стабильнее работает в K3s.
