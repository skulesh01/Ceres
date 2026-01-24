package tls

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os/exec"
)

type kubeSecret struct {
	Data map[string]string `json:"data"`
}

// ReadPEMFromKubernetesTLSSecret reads a PEM-encoded certificate from a Kubernetes Secret.
// It supports tls.crt (standard kubernetes.io/tls) and ca.crt.
func ReadPEMFromKubernetesTLSSecret(namespace, name string) ([]byte, error) {
	cmd := exec.Command("kubectl", "-n", namespace, "get", "secret", name, "-o", "json")
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("kubectl get secret %s/%s failed: %w", namespace, name, err)
	}

	var s kubeSecret
	if err := json.Unmarshal(out, &s); err != nil {
		return nil, fmt.Errorf("parse secret json: %w", err)
	}
	if s.Data == nil {
		return nil, fmt.Errorf("secret %s/%s has no data", namespace, name)
	}

	b64 := s.Data["tls.crt"]
	if b64 == "" {
		b64 = s.Data["ca.crt"]
	}
	if b64 == "" {
		return nil, fmt.Errorf("secret %s/%s missing tls.crt/ca.crt", namespace, name)
	}

	pem, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return nil, fmt.Errorf("decode secret cert: %w", err)
	}
	return pem, nil
}
