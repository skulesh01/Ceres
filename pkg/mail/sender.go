package mail

import (
	"bytes"
	"crypto/tls"
	"encoding/base64"
	"fmt"
	"net"
	"net/smtp"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

type Attachment struct {
	Filename    string
	ContentType string
	Data        []byte
}

func (m *Manager) SendEmail(to []string, subject, body string, attachments []Attachment) error {
	to = normalizeEmails(to)
	if len(to) == 0 {
		return fmt.Errorf("no recipients")
	}
	from := strings.TrimSpace(os.Getenv("CERES_MAIL_FROM"))
	if from == "" {
		from = "admin@ceres.local"
	}

	// Preferred: send via real SMTP (supports internet mail server deployments).
	if strings.TrimSpace(os.Getenv("CERES_SMTP_HOST")) != "" {
		msg, err := buildMIMEMessage(from, to, subject, body, attachments)
		if err != nil {
			return err
		}
		return sendViaSMTP(from, to, msg)
	}

	podName, err := m.getMailcowPodName()
	if err != nil {
		return err
	}

	msg, err := buildMIMEMessage(from, to, subject, body, attachments)
	if err != nil {
		return err
	}

	cmd := exec.Command("kubectl", "exec", "-n", m.namespace, podName, "-c", "postfix", "--", "sendmail", "-t")
	cmd.Stdin = strings.NewReader(msg)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("sendmail failed: %w\nOutput: %s", err, string(out))
	}
	return nil
}

func sendViaSMTP(from string, to []string, msg string) error {
	host := strings.TrimSpace(os.Getenv("CERES_SMTP_HOST"))
	port := atoiDefault(os.Getenv("CERES_SMTP_PORT"), 587)
	user := strings.TrimSpace(os.Getenv("CERES_SMTP_USER"))
	pass := strings.TrimSpace(os.Getenv("CERES_SMTP_PASS"))
	useStartTLS := parseBoolDefault(os.Getenv("CERES_SMTP_STARTTLS"), true)
	useTLS := parseBoolDefault(os.Getenv("CERES_SMTP_TLS"), false) // for implicit TLS (e.g. 465)

	addr := net.JoinHostPort(host, strconv.Itoa(port))

	var conn net.Conn
	var err error
	if useTLS {
		conn, err = tls.Dial("tcp", addr, &tls.Config{ServerName: host, MinVersion: tls.VersionTLS12})
	} else {
		conn, err = net.Dial("tcp", addr)
	}
	if err != nil {
		return fmt.Errorf("smtp connect failed (%s): %w", addr, err)
	}
	defer conn.Close()

	c, err := smtp.NewClient(conn, host)
	if err != nil {
		return fmt.Errorf("smtp client init failed: %w", err)
	}
	defer c.Quit()

	if !useTLS && useStartTLS {
		if ok, _ := c.Extension("STARTTLS"); ok {
			if err := c.StartTLS(&tls.Config{ServerName: host, MinVersion: tls.VersionTLS12}); err != nil {
				return fmt.Errorf("smtp starttls failed: %w", err)
			}
		}
	}

	if user != "" {
		if ok, _ := c.Extension("AUTH"); ok {
			auth := smtp.PlainAuth("", user, pass, host)
			if err := c.Auth(auth); err != nil {
				return fmt.Errorf("smtp auth failed: %w", err)
			}
		}
	}

	if err := c.Mail(from); err != nil {
		return fmt.Errorf("smtp MAIL FROM failed: %w", err)
	}
	for _, rcpt := range to {
		if err := c.Rcpt(rcpt); err != nil {
			return fmt.Errorf("smtp RCPT TO failed (%s): %w", rcpt, err)
		}
	}

	w, err := c.Data()
	if err != nil {
		return fmt.Errorf("smtp DATA failed: %w", err)
	}
	if _, err := w.Write([]byte(msg)); err != nil {
		_ = w.Close()
		return fmt.Errorf("smtp write failed: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("smtp close failed: %w", err)
	}
	return nil
}

func atoiDefault(s string, def int) int {
	s = strings.TrimSpace(s)
	if s == "" {
		return def
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return n
}

func parseBoolDefault(s string, def bool) bool {
	s = strings.TrimSpace(strings.ToLower(s))
	if s == "" {
		return def
	}
	switch s {
	case "1", "true", "yes", "y", "on":
		return true
	case "0", "false", "no", "n", "off":
		return false
	default:
		return def
	}
}

func (m *Manager) getMailcowPodName() (string, error) {
	cmd := exec.Command("kubectl", "get", "pods", "-n", m.namespace, "-l", "app=mailcow", "-o", "jsonpath={.items[0].metadata.name}")
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get mailcow pod name: %w", err)
	}
	pod := strings.TrimSpace(string(out))
	if pod == "" {
		return "", fmt.Errorf("mailcow pod not found")
	}
	return pod, nil
}

func buildMIMEMessage(from string, to []string, subject, body string, attachments []Attachment) (string, error) {
	toHeader := strings.Join(to, ", ")
	subject = strings.TrimSpace(subject)
	if subject == "" {
		subject = "CERES onboarding"
	}

	if len(attachments) == 0 {
		return fmt.Sprintf("From: %s\nTo: %s\nSubject: %s\nMIME-Version: 1.0\nContent-Type: text/plain; charset=utf-8\n\n%s\n", from, toHeader, subject, body), nil
	}

	boundary := fmt.Sprintf("ceres-%d", time.Now().UnixNano())
	buf := &bytes.Buffer{}
	fmt.Fprintf(buf, "From: %s\n", from)
	fmt.Fprintf(buf, "To: %s\n", toHeader)
	fmt.Fprintf(buf, "Subject: %s\n", subject)
	fmt.Fprintf(buf, "MIME-Version: 1.0\n")
	fmt.Fprintf(buf, "Content-Type: multipart/mixed; boundary=\"%s\"\n", boundary)
	fmt.Fprintf(buf, "\n")

	fmt.Fprintf(buf, "--%s\n", boundary)
	fmt.Fprintf(buf, "Content-Type: text/plain; charset=utf-8\n\n")
	fmt.Fprintf(buf, "%s\n", body)

	for _, a := range attachments {
		ct := strings.TrimSpace(a.ContentType)
		if ct == "" {
			ct = "application/octet-stream"
		}
		name := strings.TrimSpace(a.Filename)
		if name == "" {
			name = "attachment"
		}

		fmt.Fprintf(buf, "--%s\n", boundary)
		fmt.Fprintf(buf, "Content-Type: %s; name=\"%s\"\n", ct, name)
		fmt.Fprintf(buf, "Content-Transfer-Encoding: base64\n")
		fmt.Fprintf(buf, "Content-Disposition: attachment; filename=\"%s\"\n\n", name)

		enc := base64.StdEncoding.EncodeToString(a.Data)
		buf.WriteString(wrap76(enc))
		buf.WriteString("\n")
	}

	fmt.Fprintf(buf, "--%s--\n", boundary)
	return buf.String(), nil
}

func wrap76(s string) string {
	if s == "" {
		return ""
	}
	var b strings.Builder
	for len(s) > 76 {
		b.WriteString(s[:76])
		b.WriteString("\n")
		s = s[76:]
	}
	b.WriteString(s)
	return b.String()
}

func normalizeEmails(in []string) []string {
	var out []string
	for _, e := range in {
		e = strings.TrimSpace(e)
		if e == "" {
			continue
		}
		// allow comma-separated in one flag
		parts := strings.Split(e, ",")
		for _, p := range parts {
			p = strings.TrimSpace(p)
			if p != "" {
				out = append(out, p)
			}
		}
	}
	return out
}
