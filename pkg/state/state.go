package state

import (
	"context"
	"fmt"
	"strings"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

// DeploymentState manages deployment state in Kubernetes ConfigMap
type DeploymentState struct {
	client    *kubernetes.Clientset
	namespace string
	configMap string
}

// NewDeploymentState creates a new state manager
func NewDeploymentState(client *kubernetes.Clientset) *DeploymentState {
	return &DeploymentState{
		client:    client,
		namespace: "kube-system",
		configMap: "ceres-deployment-state",
	}
}

// IsInstalled checks if Ceres is already installed
func (s *DeploymentState) IsInstalled() (bool, string, error) {
	ctx := context.Background()
	cm, err := s.client.CoreV1().ConfigMaps(s.namespace).Get(ctx, s.configMap, metav1.GetOptions{})
	if err != nil {
		// ConfigMap doesn't exist = not installed
		return false, "", nil
	}

	installed := cm.Data["installed"] == "true"
	version := cm.Data["version"]
	return installed, version, nil
}

// GetServiceStatus returns status of a specific service
func (s *DeploymentState) GetServiceStatus(serviceName string) (string, error) {
	ctx := context.Background()
	cm, err := s.client.CoreV1().ConfigMaps(s.namespace).Get(ctx, s.configMap, metav1.GetOptions{})
	if err != nil {
		return "", fmt.Errorf("failed to get state: %w", err)
	}

	services := cm.Data["services"]
	for _, line := range strings.Split(services, "\n") {
		parts := strings.Split(line, ":")
		if len(parts) == 2 && strings.TrimSpace(parts[0]) == serviceName {
			return strings.TrimSpace(parts[1]), nil
		}
	}
	return "not-found", nil
}

// UpdateServiceStatus updates status of a service
func (s *DeploymentState) UpdateServiceStatus(serviceName, status string) error {
	ctx := context.Background()
	cm, err := s.client.CoreV1().ConfigMaps(s.namespace).Get(ctx, s.configMap, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get state: %w", err)
	}

	// Update services list
	services := cm.Data["services"]
	lines := strings.Split(services, "\n")
	updated := false
	for i, line := range lines {
		parts := strings.Split(line, ":")
		if len(parts) == 2 && strings.TrimSpace(parts[0]) == serviceName {
			lines[i] = fmt.Sprintf("%s: %s", serviceName, status)
			updated = true
			break
		}
	}
	if !updated {
		lines = append(lines, fmt.Sprintf("%s: %s", serviceName, status))
	}
	cm.Data["services"] = strings.Join(lines, "\n")

	_, err = s.client.CoreV1().ConfigMaps(s.namespace).Update(ctx, cm, metav1.UpdateOptions{})
	return err
}

// UpdateEndpoint saves service endpoint
func (s *DeploymentState) UpdateEndpoint(serviceName, endpoint string) error {
	ctx := context.Background()
	cm, err := s.client.CoreV1().ConfigMaps(s.namespace).Get(ctx, s.configMap, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get state: %w", err)
	}

	// Update endpoints
	endpoints := cm.Data["endpoints"]
	lines := strings.Split(endpoints, "\n")
	updated := false
	for i, line := range lines {
		parts := strings.Split(line, ":")
		if len(parts) >= 2 && strings.TrimSpace(parts[0]) == serviceName {
			lines[i] = fmt.Sprintf("%s: %s", serviceName, endpoint)
			updated = true
			break
		}
	}
	if !updated {
		lines = append(lines, fmt.Sprintf("%s: %s", serviceName, endpoint))
	}
	cm.Data["endpoints"] = strings.Join(lines, "\n")

	_, err = s.client.CoreV1().ConfigMaps(s.namespace).Update(ctx, cm, metav1.UpdateOptions{})
	return err
}

// MarkInstalled marks Ceres as installed
func (s *DeploymentState) MarkInstalled(version string) error {
	ctx := context.Background()
	cm, err := s.client.CoreV1().ConfigMaps(s.namespace).Get(ctx, s.configMap, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get state: %w", err)
	}

	cm.Data["installed"] = "true"
	cm.Data["version"] = version
	cm.Data["installDate"] = time.Now().Format(time.RFC3339)

	_, err = s.client.CoreV1().ConfigMaps(s.namespace).Update(ctx, cm, metav1.UpdateOptions{})
	return err
}

// GetAllEndpoints returns all service endpoints
func (s *DeploymentState) GetAllEndpoints() (map[string]string, error) {
	ctx := context.Background()
	cm, err := s.client.CoreV1().ConfigMaps(s.namespace).Get(ctx, s.configMap, metav1.GetOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to get state: %w", err)
	}

	endpoints := make(map[string]string)
	for _, line := range strings.Split(cm.Data["endpoints"], "\n") {
		parts := strings.Split(line, ":")
		if len(parts) >= 2 {
			key := strings.TrimSpace(parts[0])
			value := strings.TrimSpace(strings.Join(parts[1:], ":"))
			endpoints[key] = value
		}
	}
	return endpoints, nil
}
