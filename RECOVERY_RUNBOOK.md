# 🚀 RUNBOOK: Быстрое восстановление Ceres

## ⚠️ Когда сервер недоступен по SSH

### 1. Физический доступ к серверу (консоль/IPMI/Proxmox WebUI)

```bash
# Проверить статус служб
systemctl status ssh pveproxy k3s

# Запустить и включить автозапуск
systemctl enable --now ssh pveproxy k3s

# Проверить сеть
ip route show
ping -c 2 192.168.1.1  # gateway
ping -c 2 8.8.8.8      # интернет

# Если gateway недоступен (это нормально для isolated хоста)
# Проверить что есть маршрут:
ip route | grep default
# Должно быть: default via 192.168.1.1 dev vmbr0

# Проверить DNS
cat /etc/resolv.conf
# Должно быть: nameserver 8.8.8.8
```

### 2. Проверка портов
```bash
# На сервере
ss -tulpn | grep -E ':22|:8006|:6443|:30500|:51820'

# Если порты не слушают - перезапустить службы
systemctl restart ssh pveproxy k3s
```

### 3. Firewall (если pve-firewall блокирует)
```bash
# Проверить статус
pve-firewall status

# Временно отключить для диагностики
pve-firewall stop

# Или добавить правила
pve-firewall localnet -enable
```

---

## 🔄 Применение манифестов (когда SSH доступен)

### Из Windows машины:

```powershell
cd 'E:\Новая папка\Ceres'

# 1. Загрузить манифесты на сервер
$plink = ".\plink.exe"
Get-Content 'k8s-mail-vpn-simple.yaml' -Raw | & $plink -pw "!r0oT3dc" -batch root@192.168.1.3 "cat > /tmp/k8s-mail-vpn.yaml"
Get-Content 'k8s-webhook-listener-fixed.yaml' -Raw | & $plink -pw "!r0oT3dc" -batch root@192.168.1.3 "cat > /tmp/k8s-webhook.yaml"

# 2. Применить
& $plink -pw "!r0oT3dc" -batch root@192.168.1.3 "kubectl apply -f /tmp/k8s-mail-vpn.yaml -f /tmp/k8s-webhook.yaml"

# 3. Проверить pods
& $plink -pw "!r0oT3dc" -batch root@192.168.1.3 "kubectl get pods -n mail-vpn -o wide"

# 4. Если pods старые - перезапустить
& $plink -pw "!r0oT3dc" -batch root@192.168.1.3 "kubectl delete pods -n mail-vpn --all"

# 5. Ждём 90 секунд и проверяем
Start-Sleep -Seconds 90
& $plink -pw "!r0oT3dc" -batch root@192.168.1.3 "kubectl get pods -n mail-vpn"
```

---

## ✅ Проверка работоспособности

### 1. Проверить что все pods работают
```bash
kubectl get pods -n mail-vpn
# Все должны быть 1/1 Running
```

### 2. Проверить логи
```bash
# Webhook
kubectl logs -n mail-vpn -l app=webhook-listener --tail=20

# Postfix
kubectl logs -n mail-vpn -l app=postfix --tail=20

# WireGuard (если новый pod запущен)
kubectl logs -n mail-vpn -l app=wg-easy --tail=20
```

### 3. Тест webhook
```bash
# На сервере
python3 << 'EOF'
import json, requests
data = {'username': 'testuser', 'email': 'admin@ceres.local'}
headers = {'Content-Type': 'application/json', 'X-Webhook-Token': 'change-me'}
r = requests.post('http://localhost:5000/webhook/keycloak', json=data, headers=headers)
print(f'Status: {r.status_code}')
print(f'Response: {r.text}')
EOF

# Проверить WireGuard peers
wg show wg0
```

### 4. Тест с Windows
```powershell
# Проверка health
Invoke-RestMethod -Uri 'http://192.168.1.3:30500/health'

# Создание пользователя
$body = @{ username='ivan'; email='ivan@company.com' } | ConvertTo-Json
Invoke-RestMethod -Uri 'http://192.168.1.3:30500/webhook/keycloak' `
    -Method POST -Body $body -ContentType 'application/json' `
    -Headers @{'X-Webhook-Token'='change-me'}
```

---

## 🔧 Основные IP и порты

| Сервис | IP/Порт | Назначение |
|--------|---------|------------|
| SSH | 192.168.1.3:22 | Удалённый доступ |
| Proxmox WebUI | 192.168.1.3:8006 | Веб-интерфейс (если это Proxmox) |
| k3s API | 192.168.1.3:6443 | Kubernetes API |
| Webhook | 192.168.1.3:30500 | Создание VPN пользователей |
| WireGuard | 192.168.1.3:51820 | VPN сервер |
| Postfix (внутри k8s) | 10.43.28.213:25 | SMTP для email |

---

## 📝 Текущее состояние (на 02.01.2026)

✅ **Работает:**
- K3s cluster
- WireGuard VPN (10.8.0.0/24)
- Postfix SMTP (ClusterIP 10.43.28.213)
- Webhook listener (создаёт VPN peers успешно)
- Один тестовый peer создан (10.8.0.3)

⚠️ **Ограничения:**
- Нет интернета на хосте (gateway 192.168.1.1 недоступен)
- Новые Docker образы не могут скачаться (ImagePullBackOff)
- Работают только старые/кешированные pods

🔄 **Следующие шаги:**
1. Настроить интернет на хосте (если нужен) или принять что работаем офлайн
2. Протестировать полный цикл: Keycloak → webhook → VPN peer → email
3. Добавить мониторинг (Prometheus/Grafana)
4. Настроить бэкапы

---

## 🆘 Быстрая диагностика

```bash
# 1. Сервер жив?
ping 192.168.1.3

# 2. SSH доступен?
ssh root@192.168.1.3  # пароль: !r0oT3dc

# 3. K3s работает?
systemctl status k3s
kubectl get nodes

# 4. Pods запущены?
kubectl get pods -A

# 5. WireGuard работает?
wg show wg0

# 6. Webhook отвечает?
curl http://localhost:30500/health
```
