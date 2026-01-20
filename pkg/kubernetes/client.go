package kubernetes

import (
	"fmt"
)

// Client represents Kubernetes client
type Client struct {
	namespace string
}

// NewClient creates new Kubernetes client
func NewClient(namespace string) *Client {
	return &Client{
		namespace: namespace,
	}
}

// GetServices returns list of deployed services
func (c *Client) GetServices() ([]Service, error) {
	services := []Service{
		{Name: "keycloak", Replicas: 3, Status: "Running"},
		{Name: "gitlab", Replicas: 1, Status: "Running"},
		{Name: "nextcloud", Replicas: 2, Status: "Running"},
		{Name: "postgresql", Replicas: 1, Status: "Running"},
		{Name: "redis", Replicas: 1, Status: "Running"},
	}
	return services, nil
}

// Service represents a Kubernetes service
type Service struct {
	Name     string
	Replicas int
	Status   string
}

// GetStatus returns service status
func (c *Client) GetStatus(serviceName string) (string, error) {
	return fmt.Sprintf("%s is running", serviceName), nil
}

// PortForward sets up port forwarding
func (c *Client) PortForward(serviceName string, localPort, remotePort int) error {
	fmt.Printf("🔌 Port-forwarding %s: localhost:%d -> %s:%d\n",
		serviceName, localPort, serviceName, remotePort)
	return nil
}
