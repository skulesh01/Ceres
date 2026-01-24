package mail

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"os"
	"os/exec"
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
