package backup

import (
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// Manager управляет резервным копированием через Velero
type Manager struct {
	namespace string
}

// NewManager создает новый менеджер бэкапов
func NewManager() *Manager {
	return &Manager{
		namespace: "velero",
	}
}

// Install устанавливает Velero через Helm
func (m *Manager) Install() error {
	fmt.Println("📦 Устанавливаем Velero...")

	// Добавить Helm repo
	cmd := exec.Command("helm", "repo", "add", "vmware-tanzu", "https://vmware-tanzu.github.io/helm-charts")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to add helm repo: %w", err)
	}

	cmd = exec.Command("helm", "repo", "update")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to update helm repos: %w", err)
	}

	// Установить Velero
	cmd = exec.Command("helm", "install", "velero", "vmware-tanzu/velero",
		"--namespace", m.namespace,
		"--create-namespace",
		"--set", "configuration.provider=aws",
		"--set", "configuration.backupStorageLocation.bucket=ceres-backups",
		"--set", "configuration.backupStorageLocation.config.region=minio",
		"--set", "configuration.backupStorageLocation.config.s3ForcePathStyle=true",
		"--set", "configuration.backupStorageLocation.config.s3Url=http://minio.minio.svc.cluster.local:9000",
		"--set", "snapshotsEnabled=false",
		"--set", "initContainers[0].name=velero-plugin-for-aws",
		"--set", "initContainers[0].image=velero/velero-plugin-for-aws:v1.8.0",
		"--set", "initContainers[0].volumeMounts[0].mountPath=/target",
		"--set", "initContainers[0].volumeMounts[0].name=plugins",
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to install velero: %w\nOutput: %s", err, output)
	}

	fmt.Println("✅ Velero установлен")
	return nil
}

// CreateBackup создает новый бэкап
func (m *Manager) CreateBackup(name string) error {
	if name == "" {
		name = fmt.Sprintf("backup-%s", time.Now().Format("20060102-150405"))
	}

	fmt.Printf("💾 Создаем backup: %s...\n", name)

	cmd := exec.Command("kubectl", "exec", "-n", m.namespace,
		"deploy/velero", "--",
		"velero", "backup", "create", name,
		"--wait",
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to create backup: %w\nOutput: %s", err, output)
	}

	fmt.Printf("✅ Backup создан: %s\n", name)
	return nil
}

// ListBackups показывает список всех бэкапов
func (m *Manager) ListBackups() ([]string, error) {
	cmd := exec.Command("kubectl", "exec", "-n", m.namespace,
		"deploy/velero", "--",
		"velero", "backup", "get",
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("failed to list backups: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	var backups []string

	for i, line := range lines {
		if i == 0 || line == "" {
			continue // Skip header and empty lines
		}
		fields := strings.Fields(line)
		if len(fields) > 0 {
			backups = append(backups, fields[0])
		}
	}

	return backups, nil
}

// Restore восстанавливает из бэкапа
func (m *Manager) Restore(backupName string) error {
	restoreName := fmt.Sprintf("restore-%s", time.Now().Format("20060102-150405"))

	fmt.Printf("🔄 Восстанавливаем из backup: %s...\n", backupName)

	cmd := exec.Command("kubectl", "exec", "-n", m.namespace,
		"deploy/velero", "--",
		"velero", "restore", "create", restoreName,
		"--from-backup", backupName,
		"--wait",
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to restore: %w\nOutput: %s", err, output)
	}

	fmt.Printf("✅ Восстановление завершено: %s\n", restoreName)
	return nil
}

// ScheduleDaily настраивает ежедневный бэкап
func (m *Manager) ScheduleDaily() error {
	fmt.Println("⏰ Настраиваем ежедневный backup (2:00 AM)...")

	cmd := exec.Command("kubectl", "exec", "-n", m.namespace,
		"deploy/velero", "--",
		"velero", "schedule", "create", "daily-backup",
		"--schedule=0 2 * * *",
		"--ttl", "720h", // 30 дней
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to create schedule: %w\nOutput: %s", err, output)
	}

	fmt.Println("✅ Ежедневный backup настроен")
	return nil
}

// Status показывает статус Velero
func (m *Manager) Status() error {
	cmd := exec.Command("kubectl", "get", "pods", "-n", m.namespace)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to get status: %w", err)
	}

	fmt.Println(string(output))
	return nil
}
