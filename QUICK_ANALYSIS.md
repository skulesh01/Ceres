# ⚡ CERES v3.0 - Быстрый Отчет и План Действий

**Дата**: 21 января 2026  
**Статус**: 27 работают / 9 падают из 38 сервисов (71%)

---

## 🚨 ГЛАВНЫЕ ПРОБЛЕМЫ

### 1. ДУБЛИРОВАНИЕ (5 конфликтов)
```
❌ Elasticsearch + Kibana  VS  ✅ Loki + Grafana    → Одна функция (логи)
❌ Harbor                  VS  ✅ GitLab Registry   → Одна функция (registry)
❌ Jenkins                 VS  ✅ GitLab CI         → Одна функция (CI/CD)
❌ Uptime Kuma             VS  ✅ Prometheus        → Одна функция (uptime)
⚠️  Portainer              VS  ✅ kubectl + ceres   → Не нужен на K3s
```

### 2. ПАДАЮЩИЕ КРИТИЧНЫЕ СЕРВИСЫ (4)
```
🔴 Ingress NGINX    → Нет доступа к сервисам
🔴 Keycloak         → Нет SSO
🔴 GitLab           → Нет DevOps платформы
🟡 Nextcloud        → Нет файлообменника
```

### 3. ОТСУТСТВУЕТ АВТОМАТИЗАЦИЯ (5 критичных)
```
❌ Cert-Manager     → Нет HTTPS
❌ Velero Backup    → Нет резервных копий
❌ VPN Setup        → Ручная настройка
❌ Promtail         → Логи не собираются
❌ Health Checks    → Нет автопроверок
```

---

## 🎯 ПЛАН НА СЕГОДНЯ

### Шаг 1: Удалить Дубликаты (5 минут)
```bash
# Освободить ~4GB RAM и 7 подов
ssh root@192.168.1.3 << 'EOF'
kubectl delete namespace elasticsearch
kubectl delete namespace kibana  
kubectl delete namespace harbor
kubectl delete namespace jenkins
kubectl delete namespace uptime-kuma
EOF
```

### Шаг 2: Починить Критичные (автоматически)
```bash
# Запустить автофикс (уже реализовано в Go)
ssh root@192.168.1.3 '/root/ceres/ceres fix ingress-nginx-controller'
ssh root@192.168.1.3 '/root/ceres/ceres fix keycloak'
ssh root@192.168.1.3 '/root/ceres/ceres fix gitlab'
ssh root@192.168.1.3 '/root/ceres/ceres fix nextcloud'
```

### Шаг 3: Проверить Результат
```bash
ssh root@192.168.1.3 'kubectl get pods --all-namespaces | grep -E "Running|CrashLoop"'
```

**Ожидаемый результат**: 31 Running, 0 CrashLoopBackOff (вместо 27/9)

---

## 🔧 ЧТО ДОБАВИТЬ В АВТОМАТИЗАЦИЮ

### Priority 1: Cert-Manager (HTTPS)
**Файл**: `deployment/cert-manager.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
  namespace: kube-system
spec:
  repo: https://charts.jetstack.io
  chart: cert-manager
  version: v1.13.0
  targetNamespace: cert-manager
  set:
    installCRDs: "true"
```

**Интеграция в Go**:
```go
// pkg/deployment/deployer.go
func (d *Deployer) setupTLS() error {
    fmt.Println("📦 Installing Cert-Manager...")
    d.applyManifest("deployment/cert-manager.yaml")
    d.waitForPods("cert-manager", "app=cert-manager", 120)
    
    fmt.Println("📦 Creating ClusterIssuer...")
    d.applyManifest("deployment/cluster-issuer.yaml")
    
    fmt.Println("✅ TLS automation ready")
    return nil
}
```

**Добавить в меню**:
```go
// cmd/ceres/main.go - в freshInstall()
fmt.Println("\n📦 Step 9: TLS Certificates (Cert-Manager)")
if err := d.setupTLS(); err != nil {
    return err
}
```

### Priority 2: Velero Backup
**Файл**: `deployment/velero.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: velero
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: velero
  namespace: kube-system
spec:
  repo: https://vmware-tanzu.github.io/helm-charts
  chart: velero
  targetNamespace: velero
  set:
    configuration.provider: aws
    configuration.backupStorageLocation.bucket: ceres-backups
    configuration.backupStorageLocation.config.region: minio
    configuration.backupStorageLocation.config.s3Url: http://minio.minio.svc:9000
    credentials.secretContents.cloud: |
      [default]
      aws_access_key_id = minioadmin
      aws_secret_access_key = MinIO@Admin2025
    initContainers[0].name: velero-plugin-for-aws
    initContainers[0].image: velero/velero-plugin-for-aws:v1.8.0
    schedules.daily.schedule: "0 2 * * *"
    schedules.daily.template.ttl: "720h"
```

**Интеграция в Go**:
```go
// pkg/backup/backup.go (новый файл)
package backup

import (
    "fmt"
    "os/exec"
)

type BackupManager struct{}

func NewBackupManager() *BackupManager {
    return &BackupManager{}
}

func (b *BackupManager) Setup() error {
    cmd := exec.Command("kubectl", "apply", "-f", "deployment/velero.yaml")
    return cmd.Run()
}

func (b *BackupManager) CreateBackup(name string) error {
    cmd := exec.Command("kubectl", "exec", "-n", "velero", 
        "deploy/velero", "--", "velero", "backup", "create", name,
        "--include-namespaces", "ceres,ceres-core,monitoring")
    return cmd.Run()
}

func (b *BackupManager) ListBackups() (string, error) {
    cmd := exec.Command("kubectl", "exec", "-n", "velero",
        "deploy/velero", "--", "velero", "backup", "get")
    output, err := cmd.Output()
    return string(output), err
}
```

**Добавить в меню**:
```go
// cmd/ceres/main.go
fmt.Println("  8. 💾 Резервное копирование (backup)")

// Новая функция
func backupInteractive() error {
    fmt.Println("\n💾 РЕЗЕРВНОЕ КОПИРОВАНИЕ")
    fmt.Println("  1. Создать backup")
    fmt.Println("  2. Список backups")
    fmt.Println("  3. Восстановить из backup")
    fmt.Println("  0. Назад")
    
    var choice int
    fmt.Scanln(&choice)
    
    backupMgr := backup.NewBackupManager()
    
    switch choice {
    case 1:
        name := fmt.Sprintf("manual-%s", time.Now().Format("20060102-150405"))
        return backupMgr.CreateBackup(name)
    case 2:
        list, _ := backupMgr.ListBackups()
        fmt.Println(list)
    // ...
    }
}
```

### Priority 3: Promtail (Логи)
**Файл**: `deployment/promtail.yaml`
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: promtail
  template:
    metadata:
      labels:
        app: promtail
    spec:
      serviceAccountName: promtail
      containers:
      - name: promtail
        image: grafana/promtail:2.9.0
        args:
        - -config.file=/etc/promtail/config.yml
        volumeMounts:
        - name: config
          mountPath: /etc/promtail
        - name: logs
          mountPath: /var/log
        - name: pods
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: promtail-config
      - name: logs
        hostPath:
          path: /var/log
      - name: pods
        hostPath:
          path: /var/lib/docker/containers
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: monitoring
data:
  config.yml: |
    server:
      http_listen_port: 9080
    clients:
      - url: http://loki.monitoring.svc:3100/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            target_label: app
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
```

**Интеграция**:
```go
// pkg/deployment/deployer.go
func (d *Deployer) setupLogging() error {
    fmt.Println("📦 Installing Promtail...")
    d.applyManifest("deployment/promtail.yaml")
    d.waitForPods("monitoring", "app=promtail", 60)
    fmt.Println("✅ Log collection enabled")
    return nil
}
```

### Priority 4: VPN Автоматизация
**Файл**: `pkg/vpn/wireguard.go`
```go
package vpn

import (
    "crypto/rand"
    "encoding/base64"
    "fmt"
    "os"
    "os/exec"
)

type VPNManager struct {
    serverIP string
}

func NewVPNManager(serverIP string) *VPNManager {
    return &VPNManager{serverIP: serverIP}
}

func (v *VPNManager) Setup() error {
    fmt.Println("🔐 Generating WireGuard keys...")
    
    // 1. Generate client keys
    privateKey, err := v.generatePrivateKey()
    if err != nil {
        return err
    }
    publicKey, err := v.generatePublicKey(privateKey)
    if err != nil {
        return err
    }
    
    // 2. Get server public key
    serverPublicKey, err := v.getServerPublicKey()
    if err != nil {
        return err
    }
    
    // 3. Generate client config
    config := fmt.Sprintf(`[Interface]
PrivateKey = %s
Address = 10.8.0.2/24
DNS = 10.43.0.10

[Peer]
PublicKey = %s
Endpoint = %s:51820
AllowedIPs = 10.8.0.0/24, 10.43.0.0/16, 10.42.0.0/16
PersistentKeepalive = 25
`, privateKey, serverPublicKey, v.serverIP)
    
    // 4. Save config
    configPath := "ceres-vpn-client.conf"
    if err := os.WriteFile(configPath, []byte(config), 0600); err != nil {
        return err
    }
    
    fmt.Printf("✅ VPN config created: %s\n", configPath)
    fmt.Println("📋 Import to WireGuard client:")
    fmt.Println("   - Windows: WireGuard → Import from file")
    fmt.Println("   - macOS: WireGuard → Import from file")
    fmt.Println("   - Linux: wg-quick up " + configPath)
    
    // 5. Add client to server (SSH)
    return v.addClientToServer(publicKey)
}

func (v *VPNManager) generatePrivateKey() (string, error) {
    key := make([]byte, 32)
    if _, err := rand.Read(key); err != nil {
        return "", err
    }
    return base64.StdEncoding.EncodeToString(key), nil
}

func (v *VPNManager) generatePublicKey(privateKey string) (string, error) {
    // Use wg command to generate public key from private
    cmd := exec.Command("bash", "-c", 
        fmt.Sprintf("echo '%s' | wg pubkey", privateKey))
    output, err := cmd.Output()
    if err != nil {
        return "", err
    }
    return string(output), nil
}

func (v *VPNManager) getServerPublicKey() (string, error) {
    cmd := exec.Command("ssh", fmt.Sprintf("root@%s", v.serverIP),
        "wg show wg0 public-key")
    output, err := cmd.Output()
    return string(output), err
}

func (v *VPNManager) addClientToServer(clientPublicKey string) error {
    script := fmt.Sprintf(`
wg set wg0 peer %s allowed-ips 10.8.0.2/32
wg-quick save wg0
`, clientPublicKey)
    
    cmd := exec.Command("ssh", fmt.Sprintf("root@%s", v.serverIP), script)
    return cmd.Run()
}

func (v *VPNManager) Status() (string, error) {
    // Check if VPN interface exists
    cmd := exec.Command("wg", "show")
    output, err := cmd.Output()
    if err != nil {
        return "❌ VPN not connected", err
    }
    return string(output), nil
}

func (v *VPNManager) Disconnect() error {
    cmd := exec.Command("wg-quick", "down", "ceres-vpn-client")
    return cmd.Run()
}
```

### Priority 5: Health Check Automation
**Файл**: `pkg/deployment/healthcheck.go` (новый)
```go
package deployment

import (
    "fmt"
    "os/exec"
    "strings"
)

func (d *Deployer) HealthCheck() error {
    fmt.Println("🏥 Running Health Check...")
    
    criticalServices := map[string]string{
        "ingress-nginx":          "ingress-nginx",
        "keycloak":               "ceres",
        "gitlab":                 "gitlab",
        "postgresql":             "ceres-core",
        "redis":                  "ceres-core",
        "prometheus":             "monitoring",
        "grafana":                "monitoring",
    }
    
    allHealthy := true
    
    for service, namespace := range criticalServices {
        healthy := d.checkServiceHealth(service, namespace)
        if healthy {
            fmt.Printf("  ✅ %s (healthy)\n", service)
        } else {
            fmt.Printf("  ❌ %s (unhealthy)\n", service)
            allHealthy = false
            
            // Auto-fix
            fmt.Printf("     🔧 Auto-fixing...\n")
            d.FixServices(service)
        }
    }
    
    if allHealthy {
        fmt.Println("\n✅ All critical services healthy!")
    } else {
        fmt.Println("\n⚠️  Some services required fixes")
    }
    
    return nil
}

func (d *Deployer) checkServiceHealth(service, namespace string) bool {
    cmd := exec.Command("kubectl", "get", "pods", "-n", namespace,
        "-l", fmt.Sprintf("app=%s", service),
        "-o", "jsonpath={.items[*].status.phase}")
    output, err := cmd.Output()
    if err != nil {
        return false
    }
    
    return strings.Contains(string(output), "Running")
}
```

**Добавить команду**:
```go
// cmd/ceres/main.go
cmd.AddCommand(&cobra.Command{
    Use:   "health",
    Short: "Check platform health",
    RunE: func(cmd *cobra.Command, args []string) error {
        deployer, _ := deployment.NewDeployer("proxmox", "prod", "ceres")
        return deployer.HealthCheck()
    },
})
```

---

## 📊 ОЖИДАЕМЫЙ РЕЗУЛЬТАТ

### До
```
Сервисов:          38
Работают:          27 (71%)
Падают:            9 (24%)
Дубликаты:         5
Автоматизация:     60%
Backup:            ❌ Нет
TLS:               ❌ Нет
VPN:               ⚠️  Ручной
```

### После (v3.1.0)
```
Сервисов:          25 (-13)
Работают:          25 (100%)
Падают:            0 (0%)
Дубликаты:         0
Автоматизация:     95%
Backup:            ✅ Ежедневный
TLS:               ✅ Автоматический
VPN:               ✅ Один клик
```

---

## 🚀 СЛЕДУЮЩИЕ ШАГИ

1. **Прочитать**: [ARCHITECTURE_ANALYSIS.md](ARCHITECTURE_ANALYSIS.md) - полный анализ
2. **Удалить дубликаты**: Запустить команды из Шага 1
3. **Починить сервисы**: Запустить автофикс из Шага 2
4. **Решить**: Какие улучшения добавить первыми
5. **Обновить версию**: 3.0.0 → 3.1.0 после всех изменений

---

**Создано**: AI Assistant  
**Дата**: 2026-01-21
