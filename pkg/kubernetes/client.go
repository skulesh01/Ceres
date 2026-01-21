package kubernetes

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// Client represents Kubernetes client
type Client struct {
	namespace  string
	clientset  *kubernetes.Clientset
	kubeconfig string
}

// NewClient creates new Kubernetes client
func NewClient(namespace string) (*Client, error) {
	// Get kubeconfig path
	kubeconfig := os.Getenv("KUBECONFIG")
	if kubeconfig == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("failed to get home directory: %w", err)
		}
		kubeconfig = filepath.Join(home, ".kube", "config")
	}

	// Build config
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		return nil, fmt.Errorf("failed to build kubeconfig: %w", err)
	}

	// Create clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create kubernetes client: %w", err)
	}

	return &Client{
		namespace:  namespace,
		clientset:  clientset,
		kubeconfig: kubeconfig,
	}, nil
}

// GetServices returns list of deployed services
func (c *Client) GetServices() ([]Service, error) {
	ctx := context.Background()
	deployments, err := c.clientset.AppsV1().Deployments(c.namespace).List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to list deployments: %w", err)
	}

	var services []Service
	for _, deploy := range deployments.Items {
		status := "Unknown"
		if deploy.Status.ReadyReplicas == *deploy.Spec.Replicas {
			status = "Running"
		} else if deploy.Status.ReadyReplicas > 0 {
			status = "Degraded"
		} else {
			status = "Failed"
		}

		services = append(services, Service{
			Name:     deploy.Name,
			Replicas: int(*deploy.Spec.Replicas),
			Ready:    int(deploy.Status.ReadyReplicas),
			Status:   status,
		})
	}

	return services, nil
}

// Service represents a Kubernetes service
type Service struct {
	Name     string
	Replicas int
	Ready    int
	Status   string
}

// GetStatus returns service status
func (c *Client) GetStatus(serviceName string) (string, error) {
	ctx := context.Background()
	deploy, err := c.clientset.AppsV1().Deployments(c.namespace).Get(ctx, serviceName, metav1.GetOptions{})
	if err != nil {
		return "", fmt.Errorf("failed to get deployment: %w", err)
	}

	return fmt.Sprintf("%s: %d/%d replicas ready",
		deploy.Name, deploy.Status.ReadyReplicas, *deploy.Spec.Replicas), nil
}

// GetPods returns list of pods in namespace
func (c *Client) GetPods() ([]Pod, error) {
	ctx := context.Background()
	pods, err := c.clientset.CoreV1().Pods(c.namespace).List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to list pods: %w", err)
	}

	var result []Pod
	for _, pod := range pods.Items {
		result = append(result, Pod{
			Name:   pod.Name,
			Status: string(pod.Status.Phase),
		})
	}

	return result, nil
}

// Pod represents a Kubernetes pod
type Pod struct {
	Name   string
	Status string
}

// CreateNamespace creates a new namespace
func (c *Client) CreateNamespace(name string) error {
	ctx := context.Background()
	_, err := c.clientset.CoreV1().Namespaces().Get(ctx, name, metav1.GetOptions{})
	if err == nil {
		fmt.Printf("  ✓ Namespace %s already exists\n", name)
		return nil
	}

	cmd := exec.Command("kubectl", "create", "namespace", name)
	output, err := cmd.CombinedOutput()
	if err != nil {
		if strings.Contains(string(output), "already exists") {
			fmt.Printf("  ✓ Namespace %s already exists\n", name)
			return nil
		}
		return fmt.Errorf("failed to create namespace: %w\nOutput: %s", err, string(output))
	}

	fmt.Printf("  ✓ Namespace %s created\n", name)
	return nil
}

// ApplyManifest applies a Kubernetes manifest
func (c *Client) ApplyManifest(manifest string) error {
	cmd := exec.Command("kubectl", "apply", "-f", "-", "-n", c.namespace)
	cmd.Stdin = strings.NewReader(manifest)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to apply manifest: %w\nOutput: %s", err, string(output))
	}
	return nil
}
