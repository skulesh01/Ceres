package mail

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func isExternalMailMode() bool {
	mode := strings.TrimSpace(strings.ToLower(os.Getenv("CERES_MAIL_MODE")))
	if mode == "external" {
		return true
	}
	skip := strings.TrimSpace(strings.ToLower(os.Getenv("CERES_SKIP_MAILCOW")))
	return skip == "1" || skip == "true" || skip == "yes" || skip == "y" || skip == "on"
}

// Manager управляет почтовым сервером Mailcow
type Manager struct {
	namespace string
}

// NewManager создает новый менеджер почты
func NewManager() *Manager {
	return &Manager{
		namespace: "mailcow",
	}
}

// Install устанавливает Mailcow
func (m *Manager) Install() error {
	if isExternalMailMode() {
		fmt.Println("📧 External mail mode enabled; skipping Mailcow install")
		m.showAccessInfo()
		return nil
	}
	fmt.Println("📧 Устанавливаем Mailcow...")

	// Apply manifest
	cmd := exec.Command("kubectl", "apply", "-f", "deployment/mailcow.yaml")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to install mailcow: %w\nOutput: %s", err, output)
	}

	fmt.Println("⏳ Ожидаем готовности Mailcow...")
	cmd = exec.Command("kubectl", "wait", "--for=condition=ready", "pod",
		"-l", "app=mailcow",
		"-n", m.namespace,
		"--timeout=300s",
	)
	
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("mailcow pods failed to become ready: %w", err)
	}

	fmt.Println("✅ Mailcow установлен")
	m.showAccessInfo()
	return nil
}

// ConfigureSMTP настраивает SMTP для сервисов
func (m *Manager) ConfigureSMTP(service string) error {
	fmt.Printf("📨 Настраиваем SMTP для %s...\n", service)

	smtpConfigs := map[string]string{
		"gitlab":     "deployment/smtp-configs/gitlab-smtp.yaml",
		"mattermost": "deployment/smtp-configs/mattermost-smtp.yaml",
		"keycloak":   "deployment/smtp-configs/keycloak-smtp.yaml",
		"alertmanager": "deployment/smtp-configs/alertmanager-smtp.yaml",
	}

	configFile, ok := smtpConfigs[service]
	if !ok {
		return fmt.Errorf("unknown service: %s", service)
	}

	cmd := exec.Command("kubectl", "apply", "-f", configFile)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to configure SMTP: %w\nOutput: %s", err, output)
	}

	fmt.Printf("✅ SMTP настроен для %s\n", service)
	return nil
}

// SendTestEmail отправляет тестовое письмо
func (m *Manager) SendTestEmail(to string) error {
	fmt.Printf("📬 Отправляем тестовое письмо на %s...\n", to)

	if strings.TrimSpace(os.Getenv("CERES_SMTP_HOST")) != "" {
		return m.SendEmail([]string{to}, "CERES Test Email", "This is a test email from CERES.", nil)
	}

	// Get postfix pod
	cmd := exec.Command("kubectl", "get", "pods", "-n", m.namespace,
		"-l", "app=mailcow",
		"-o", "jsonpath={.items[0].metadata.name}",
	)
	podName, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get pod name: %w", err)
	}

	// Send test email
	emailBody := fmt.Sprintf("From: admin@ceres.local\nTo: %s\nSubject: CERES Test Email\n\nThis is a test email from CERES v3.1 Mailcow installation.", to)
	
	cmd = exec.Command("kubectl", "exec", "-n", m.namespace, string(podName),
		"-c", "postfix", "--",
		"sendmail", to,
	)
	cmd.Stdin = strings.NewReader(emailBody)
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to send email: %w\nOutput: %s", err, output)
	}

	fmt.Println("✅ Тестовое письмо отправлено")
	return nil
}

// Status показывает статус Mailcow
func (m *Manager) Status() error {
	if isExternalMailMode() {
		m.showAccessInfo()
		return nil
	}
	cmd := exec.Command("kubectl", "get", "pods,svc", "-n", m.namespace)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to get status: %w", err)
	}

	fmt.Println(string(output))
	return nil
}

// showAccessInfo показывает информацию о доступе
func (m *Manager) showAccessInfo() {
	fmt.Println("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("📧 MAILCOW ACCESS INFO")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	if isExternalMailMode() {
		fmt.Println("🌐 External mail: configured outside Kubernetes")
		if h := strings.TrimSpace(os.Getenv("CERES_SMTP_HOST")); h != "" {
			fmt.Printf("📨 SMTP: %s:%s\n", h, strings.TrimSpace(os.Getenv("CERES_SMTP_PORT")))
		} else {
			fmt.Println("📨 SMTP: (not set) set CERES_SMTP_HOST/CERES_SMTP_PORT/CERES_SMTP_USER/CERES_SMTP_PASS")
		}
		fmt.Println("🔐 IMAP/POP3/Webmail: depends on your external mail solution")
	} else {
		fmt.Println("🌐 Webmail: http://mail.ceres.local")
		fmt.Println("📨 SMTP (internal): mailcow-smtp.mailcow.svc:587")
		fmt.Println("📬 IMAP: mailcow-imap.mailcow.svc:993")
		fmt.Println("🔐 Домен: @ceres.local")
	}
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
}
