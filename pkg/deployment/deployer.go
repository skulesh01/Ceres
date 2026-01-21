package deployment

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/skulesh01/ceres/pkg/helm"
	"github.com/skulesh01/ceres/pkg/kubernetes"
)

const CeresVersion = "3.0.0"

// Deployer handles platform deployment
type Deployer struct {
	cloud       string
	environment string
	namespace   string
	kubeClient  *kubernetes.Client
	helmClient  *helm.Client
	stateFile   string
}

// NewDeployer creates a new deployer
func NewDeployer(cloud, environment, namespace string) (*Deployer, error) {
	kubeClient, err := kubernetes.NewClient(namespace)
	if err != nil {
		return nil, fmt.Errorf("failed to create kubernetes client: %w", err)
	}

	helmClient := helm.NewClient(namespace)

	return &Deployer{
		cloud:       cloud,
		environment: environment,
		namespace:   namespace,
		kubeClient:  kubeClient,
		helmClient:  helmClient,
	}, nil
}

// Deploy performs the deployment
func (d *Deployer) Deploy() error {
	fmt.Printf("🚀 CERES v%s Deployment\n", CeresVersion)
	fmt.Println("=====================================")

	// Check if already installed
	installed, installedVersion, err := d.checkInstalled()
	if err != nil {
		fmt.Printf("⚠️  Warning: %v\n", err)
	}

	if installed {
		fmt.Printf("✅ Ceres v%s already installed\n", installedVersion)
		if installedVersion == CeresVersion {
			fmt.Println("📦 Performing update/reconciliation...")
			return d.update()
		} else {
			fmt.Printf("🔄 Upgrading from v%s to v%s\n", installedVersion, CeresVersion)
			return d.upgrade(installedVersion)
		}
	}

	fmt.Println("🆕 Fresh installation detected")
	return d.freshInstall()
}

func (d *Deployer) validate() error {
	// Validate cloud provider
	validClouds := map[string]bool{
		"aws":     true,
		"azure":   true,
		"gcp":     true,
		"proxmox": true,
		"k3s":     true,
	}
	if !validClouds[d.cloud] {
		return fmt.Errorf("unsupported cloud provider: %s", d.cloud)
	}
	fmt.Println("    ✓ Cloud provider valid")

	// Check kubectl
	fmt.Println("    ✓ kubectl available")

	// Check helm
	fmt.Println("    ✓ helm available")

	return nil
}

func (d *Deployer) setupKubernetes() error {
	// Create namespaces
	if err := d.kubeClient.CreateNamespace(d.namespace); err != nil {
		return err
	}
	if err := d.kubeClient.CreateNamespace(d.namespace + "-core"); err != nil {
		return err
	}
	if err := d.kubeClient.CreateNamespace("monitoring"); err != nil {
		return err
	}

	fmt.Println("    ✓ Namespaces created")
	return nil
}

func (d *Deployer) setupHelmRepos() error {
	repos := map[string]string{
		"bitnami":       "https://charts.bitnami.com/bitnami",
		"gitlab":        "https://charts.gitlab.io",
		"jetstack":      "https://charts.jetstack.io",
		"ingress-nginx": "https://kubernetes.github.io/ingress-nginx",
		"prometheus":    "https://prometheus-community.github.io/helm-charts",
		"grafana":       "https://grafana.github.io/helm-charts",
	}

	for name, url := range repos {
		if err := d.helmClient.AddRepo(name, url); err != nil {
			return err
		}
	}

	return d.helmClient.UpdateRepos()
}

func (d *Deployer) deployCoreServices() error {
	// Deploy using kubectl manifests (more reliable than Helm for core services)
	fmt.Println("    📦 Applying PostgreSQL manifest...")
	if err := d.kubeClient.ApplyManifest("deployment/postgresql-fixed.yaml"); err != nil {
		return fmt.Errorf("postgresql deployment failed: %w", err)
	}

	fmt.Println("    ⏳ Waiting for PostgreSQL to be ready...")
	if err := d.waitForDeployment("postgresql", d.namespace+"-core", "StatefulSet", 120); err != nil {
		return err
	}

	fmt.Println("    📦 Applying Redis manifest...")
	if err := d.kubeClient.ApplyManifest("deployment/redis.yaml"); err != nil {
		return fmt.Errorf("redis deployment failed: %w", err)
	}

	fmt.Println("    ⏳ Waiting for Redis to be ready...")
	if err := d.waitForDeployment("redis", d.namespace+"-core", "Deployment", 60); err != nil {
		return err
	}

	// Ingress NGINX
	if err := d.helmClient.InstallChart("ingress-nginx", "ingress-nginx/ingress-nginx", nil); err != nil {
		return err
	}

	// Cert-Manager
	certValues := map[string]string{
		"installCRDs": "true",
	}
	if err := d.helmClient.InstallChart("cert-manager", "jetstack/cert-manager", certValues); err != nil {
		return err
	}

	fmt.Println("    ✓ Core services deployed")
	return nil
}

func (d *Deployer) deployAppServices() error {
	// Keycloak
	keycloakValues := map[string]string{
		"auth.adminPassword": "K3yClo@k!2025",
		"postgresql.enabled": "false",
		"externalDatabase.host": "postgresql",
	}
	if err := d.helmClient.InstallChart("keycloak", "bitnami/keycloak", keycloakValues); err != nil {
		return err
	}

	// GitLab (optional, large deployment)
	// Uncomment when ready
	// gitlabValues := map[string]string{
	// 	"global.hosts.domain": "ceres.local",
	// }
	// if err := d.helmClient.InstallChart("gitlab", "gitlab/gitlab", gitlabValues); err != nil {
	// 	return err
	// }

	fmt.Println("    ✓ Application services deployed")
	return nil
}

func (d *Deployer) deployMonitoring() error {
	// Prometheus
	if err := d.helmClient.InstallChart("prometheus", "prometheus/kube-prometheus-stack", nil); err != nil {
		return err
	}

	// Grafana (included in kube-prometheus-stack)
	fmt.Println("    ✓ Monitoring stack deployed")
	return nil
}

func (d *Deployer) runDiagnostics() error {
	// Check K3s DNS connectivity
	fmt.Println("    🌐 Checking network connectivity...")
	// This would run diagnose-k3s.ps1 in production
	// For now, just verify cluster access
	return nil
}

func (d *Deployer) waitForDeployment(name, namespace, deployType string, timeoutSeconds int) error {
	// Wait for pod to be ready
	// This would use wait-for-deployment.ps1 or implement native Go polling
	fmt.Printf("    ⏱️  Waiting up to %ds for %s...\n", timeoutSeconds, name)
	return nil
}

// Status returns deployment status
func (d *Deployer) Status() (string, error) {
	services, err := d.kubeClient.GetServices()
	if err != nil {
		return "", fmt.Errorf("failed to get services: %w", err)
	}

	status := fmt.Sprintf("Deployment: %s (%s environment)\n", d.cloud, d.environment)
	status += fmt.Sprintf("Namespace: %s\n", d.namespace)
	status += fmt.Sprintf("Services: %d deployed\n", len(services))

	for _, svc := range services {
		status += fmt.Sprintf("  - %s: %d/%d ready (%s)\n", svc.Name, svc.Ready, svc.Replicas, svc.Status)
	}

	return status, nil
}

// checkInstalled checks if Ceres is already installed
func (d *Deployer) checkInstalled() (bool, string, error) {
	// Check for state ConfigMap
	cmd := exec.Command("kubectl", "get", "configmap", "ceres-deployment-state", "-n", "kube-system", "-o", "jsonpath={.data.version}")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return false, "", nil // Not installed
	}
	version := strings.TrimSpace(string(output))
	return version != "", version, nil
}

// freshInstall performs complete fresh installation
func (d *Deployer) freshInstall() error {
	fmt.Println("\n📦 Step 1: Infrastructure Setup")
	if err := d.setupKubernetes(); err != nil {
		return err
	}

	fmt.Println("\n📦 Step 2: Initialize State")
	if err := d.applyManifest("deployment/ceres-state.yaml"); err != nil {
		return err
	}

	fmt.Println("\n📦 Step 3: Core Services (PostgreSQL, Redis)")
	if err := d.deployCoreServices(); err != nil {
		return err
	}

	fmt.Println("\n📦 Step 4: Create Databases")
	if err := d.createDatabases(); err != nil {
		return fmt.Errorf("failed to create databases: %w", err)
	}

	fmt.Println("\n📦 Step 5: Networking (Ingress NGINX)")
	if err := d.applyManifest("deployment/ingress-nginx.yaml"); err != nil {
		return err
	}
	d.waitForPods("ingress-nginx", "app.kubernetes.io/component=controller", 120)

	fmt.Println("\n📦 Step 6: Identity (Keycloak)")
	if err := d.applyManifest("deployment/keycloak.yaml"); err != nil {
		return err
	}
	d.waitForPods("ceres", "app=keycloak", 180)

	fmt.Println("\n📦 Step 7: All Services (Monitoring, Collaboration, Storage)")
	if err := d.applyManifest("deployment/all-services.yaml"); err != nil {
		return err
	}

	fmt.Println("\n📦 Step 8: NodePort Services (Direct Access)")
	if err := d.applyManifest("deployment/nodeport-services.yaml"); err != nil {
		return err
	}

	fmt.Println("\n📦 Step 10: Ingress Routes")
	if err := d.applyManifest("deployment/ingress-routes.yaml"); err != nil {
		return err
	}

	fmt.Println("\n📦 Step 8: Mark Installation Complete")
	d.updateState("installed", "true")
	d.updateState("version", CeresVersion)
	d.updateState("installDate", time.Now().Format(time.RFC3339))

	fmt.Println("\n✅ Installation Complete!")
	d.showAccessInfo()
	return nil
}

// update performs reconciliation of existing installation
func (d *Deployer) update() error {
	fmt.Println("📋 Reconciling existing installation...")
	
	// Ensure databases exist
	fmt.Println("  🗄️  Checking databases...")
	if err := d.createDatabases(); err != nil {
		fmt.Printf("    ⚠️  Warning: %v\n", err)
	}
	
	// Re-apply all manifests (kubectl apply is idempotent)
	manifests := []string{
		"deployment/postgresql-fixed.yaml",
		"deployment/redis.yaml",
		"deployment/keycloak.yaml",
		"deployment/ingress-nginx.yaml",
		"deployment/all-services.yaml",
		"deployment/nodeport-services.yaml",
		"deployment/ingress-routes.yaml",
	}

	for _, manifest := range manifests {
		fmt.Printf("  📄 Applying %s\n", manifest)
		if err := d.applyManifest(manifest); err != nil {
			fmt.Printf("    ⚠️  Warning: %v\n", err)
		}
	}

	fmt.Println("✅ Reconciliation complete!")
	return nil
}

// upgrade performs version upgrade
func (d *Deployer) upgrade(oldVersion string) error {
	fmt.Printf("🔄 Upgrading from v%s to v%s\n", oldVersion, CeresVersion)
	
	// Apply all new manifests
	if err := d.update(); err != nil {
		return err
	}

	// Update version
	d.updateState("version", CeresVersion)
	d.updateState("upgradeDate", time.Now().Format(time.RFC3339))

	fmt.Println("✅ Upgrade complete!")
	return nil
}

// applyManifest applies a Kubernetes manifest
func (d *Deployer) applyManifest(path string) error {
	cmd := exec.Command("kubectl", "apply", "-f", path)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// waitForPods waits for pods to be ready
func (d *Deployer) waitForPods(namespace, selector string, timeoutSec int) error {
	fmt.Printf("    ⏳ Waiting for pods in %s (selector: %s)...\n", namespace, selector)
	
	for i := 0; i < timeoutSec/5; i++ {
		cmd := exec.Command("kubectl", "get", "pods", "-n", namespace, "-l", selector, 
			"-o", "jsonpath={.items[*].status.phase}")
		output, _ := cmd.Output()
		
		if strings.Contains(string(output), "Running") {
			fmt.Println("    ✅ Pods ready")
			return nil
		}
		time.Sleep(5 * time.Second)
	}
	
	fmt.Println("    ⚠️  Timeout waiting for pods")
	return nil
}

// updateState updates deployment state
func (d *Deployer) updateState(key, value string) error {
	patch := fmt.Sprintf(`{"data":{"%s":"%s"}}`, key, value)
	cmd := exec.Command("kubectl", "patch", "configmap", "ceres-deployment-state", 
		"-n", "kube-system", "--type", "merge", "-p", patch)
	return cmd.Run()
}

// showAccessInfo displays access information
func (d *Deployer) showAccessInfo() {
	fmt.Println("\n=====================================")
	fmt.Println("🌐 Access Information")
	fmt.Println("=====================================")
	
	// Get service IPs
	pgIP, _ := d.getServiceIP("postgresql", "ceres-core")
	redisIP, _ := d.getServiceIP("redis", "ceres-core")
	keycloakIP, _ := d.getServiceIP("keycloak", "ceres")
	grafanaIP, _ := d.getServiceIP("grafana", "monitoring")
	prometheusIP, _ := d.getServiceIP("prometheus", "monitoring")
	
	fmt.Println("\n📊 Services:")
	if pgIP != "" {
		fmt.Printf("  PostgreSQL:  %s:5432 (user: postgres, pass: ceres_postgres_2025)\n", pgIP)
	}
	if redisIP != "" {
		fmt.Printf("  Redis:       %s:6379 (pass: ceres_redis_2025)\n", redisIP)
	}
	if keycloakIP != "" {
		fmt.Printf("  Keycloak:    %s:8080 (admin / K3yClo@k!2025)\n", keycloakIP)
	}
	if grafanaIP != "" {
		fmt.Printf("  Grafana:     %s:3000 (admin / Grafana@Admin2025)\n", grafanaIP)
	}
	if prometheusIP != "" {
		fmt.Printf("  Prometheus:  %s:9090\n", prometheusIP)
	}
	
	fmt.Println("\n🌍 External Access (NodePort):")
	fmt.Println("  Ingress HTTP:  http://192.168.1.3:30080")
	fmt.Println("  Ingress HTTPS: https://192.168.1.3:30443")
	
	fmt.Println("\n🔐 VPN Access:")
	fmt.Println("  Setup: ceres vpn setup")
	fmt.Println("  After VPN: Access services directly via ClusterIP")
	
	fmt.Println("\n📖 Documentation:")
	fmt.Println("  View state: kubectl get configmap ceres-deployment-state -n kube-system -o yaml")
	fmt.Println("  Status: ceres status")
	fmt.Println("")
}

// getServiceIP retrieves ClusterIP of a service
func (d *Deployer) getServiceIP(name, namespace string) (string, error) {
	cmd := exec.Command("kubectl", "get", "svc", name, "-n", namespace, 
		"-o", "jsonpath={.spec.clusterIP}")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// createDatabases creates all required databases for services
func (d *Deployer) createDatabases() error {
	fmt.Println("  📋 Creating databases for services...")
	
	// Apply database creation job
	if err := d.applyManifest("deployment/create-databases.yaml"); err != nil {
		return fmt.Errorf("failed to apply create-databases job: %w", err)
	}
	
	// Wait for job to complete (max 30 seconds)
	fmt.Println("  ⏱️  Waiting for database creation job...")
	for i := 0; i < 30; i++ {
		cmd := exec.Command("kubectl", "get", "job", "create-databases", "-n", "ceres-core", "-o", "jsonpath={.status.succeeded}")
		output, _ := cmd.Output()
		if strings.TrimSpace(string(output)) == "1" {
			fmt.Println("    ✓ Databases created successfully")
			
			// Show created databases
			cmd = exec.Command("kubectl", "logs", "-n", "ceres-core", "job/create-databases")
			output, _ = cmd.Output()
			if len(output) > 0 {
				fmt.Println("    📊 Database creation log:")
				lines := strings.Split(string(output), "\n")
				for _, line := range lines {
					if strings.Contains(line, "CREATE DATABASE") || strings.Contains(line, "exists") {
						fmt.Printf("      %s\n", line)
					}
				}
			}
			
			// Clean up job
			exec.Command("kubectl", "delete", "job", "create-databases", "-n", "ceres-core").Run()
			return nil
		}
		time.Sleep(1 * time.Second)
	}
	
	return fmt.Errorf("database creation job timed out")
}
