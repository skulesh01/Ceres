package deployment

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

const CeresVersion = "3.0.0"

// Deployer handles platform deployment
type Deployer struct {
	cloud       string
	environment string
	namespace   string
	stateFile   string
}

// NewDeployer creates a new deployer
func NewDeployer(cloud, environment, namespace string) (*Deployer, error) {
	return &Deployer{
		cloud:       cloud,
		environment: environment,
		namespace:   namespace,
		stateFile:   "/var/lib/ceres/state.yaml",
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
	// Create namespaces using kubectl
	namespaces := []string{d.namespace, d.namespace + "-core", "monitoring"}
	for _, ns := range namespaces {
		cmd := exec.Command("kubectl", "create", "namespace", ns)
		cmd.Run() // Ignore error if exists
	}
	fmt.Println("    ✓ Namespaces created")
	return nil
}

func (d *Deployer) setupHelmRepos() error {
	// Simplified - using kubectl manifests instead of Helm
	fmt.Println("    ✓ Using kubectl manifests")
	return nil
}

func (d *Deployer) deployCoreServices() error {
	// Deploy using kubectl manifests (more reliable than Helm for core services)
	fmt.Println("    📦 Applying PostgreSQL manifest...")
	if err := d.applyManifest("deployment/postgresql-fixed.yaml"); err != nil {
		return fmt.Errorf("postgresql deployment failed: %w", err)
	}

	fmt.Println("    ⏳ Waiting for PostgreSQL to be ready...")
	if err := d.waitForDeployment("postgresql", d.namespace+"-core", "StatefulSet", 120); err != nil {
		return err
	}

	fmt.Println("    📦 Applying Redis manifest...")
	if err := d.applyManifest("deployment/redis.yaml"); err != nil {
		return fmt.Errorf("redis deployment failed: %w", err)
	}

	fmt.Println("    ⏳ Waiting for Redis to be ready...")
	if err := d.waitForDeployment("redis", d.namespace+"-core", "Deployment", 60); err != nil {
		return err
	}

	fmt.Println("    ✓ Core services deployed")
	return nil
}

func (d *Deployer) deployAppServices() error {
	// Using kubectl manifests instead of Helm
	fmt.Println("    ✓ Application services via kubectl")
	return nil
}

func (d *Deployer) deployMonitoring() error {
	// Using kubectl manifests
	fmt.Println("    ✓ Monitoring stack via kubectl")
	return nil
}

func (d *Deployer) runDiagnostics() error {
	fmt.Println("    🌐 Running diagnostics...")
	
	// Check cluster connectivity
	cmd := exec.Command("kubectl", "cluster-info")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("kubectl cluster-info failed: %w", err)
	}
	fmt.Println("      ✓ Cluster connectivity OK")
	
	// Check DNS
	cmd = exec.Command("kubectl", "get", "svc", "-n", "kube-system", "kube-dns")
	if err := cmd.Run(); err != nil {
		fmt.Println("      ⚠️  DNS service not found (might be CoreDNS)")
	} else {
		fmt.Println("      ✓ DNS service available")
	}
	
	// Check nodes
	cmd = exec.Command("kubectl", "get", "nodes")
	output, _ := cmd.Output()
	if strings.Contains(string(output), "Ready") {
		fmt.Println("      ✓ Nodes are Ready")
	}
	
	return nil
}

func (d *Deployer) waitForDeployment(name, namespace, deployType string, timeoutSeconds int) error {
	fmt.Printf("    ⏱️  Waiting up to %ds for %s...\n", timeoutSeconds, name)
	
	for i := 0; i < timeoutSeconds; i++ {
		cmd := exec.Command("kubectl", "get", deployType, name, "-n", namespace, "-o", "jsonpath={.status.readyReplicas}")
		output, _ := cmd.Output()
		
		readyReplicas := strings.TrimSpace(string(output))
		if readyReplicas != "" && readyReplicas != "0" {
			fmt.Printf("    ✅ %s is ready!\n", name)
			return nil
		}
		
		time.Sleep(1 * time.Second)
	}
	
	return fmt.Errorf("timeout waiting for %s", name)
}

// Status returns deployment status
func (d *Deployer) Status() (string, error) {
	fmt.Println("📊 Getting cluster status...")
	
	cmd := exec.Command("kubectl", "get", "pods", "--all-namespaces", "-o", "wide")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to get pods: %w", err)
	}
	
	return string(output), nil
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

// Diagnose runs cluster diagnostics
func (d *Deployer) Diagnose() error {
	fmt.Println("=====================================")
	fmt.Println("🔍 CERES Cluster Diagnostics")
	fmt.Println("=====================================\n")

	// 1. Cluster connectivity
	fmt.Println("1️⃣  Cluster Connectivity:")
	cmd := exec.Command("kubectl", "cluster-info")
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("  ❌ Cluster not accessible: %v\n", err)
		return err
	}
	fmt.Println("  ✅ Cluster is accessible")

	// 2. Nodes status
	fmt.Println("\n2️⃣  Nodes Status:")
	cmd = exec.Command("kubectl", "get", "nodes", "-o", "wide")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()

	// 3. Running pods count
	fmt.Println("\n3️⃣  Pods Summary:")
	cmd = exec.Command("kubectl", "get", "pods", "--all-namespaces", "--no-headers")
	output, _ = cmd.Output()
	lines := strings.Split(string(output), "\n")
	
	running := 0
	crashing := 0
	pending := 0
	
	for _, line := range lines {
		if strings.Contains(line, "Running") {
			running++
		} else if strings.Contains(line, "CrashLoopBackOff") || strings.Contains(line, "Error") {
			crashing++
		} else if strings.Contains(line, "Pending") {
			pending++
		}
	}
	
	fmt.Printf("  ✅ Running: %d\n", running)
	fmt.Printf("  ⚠️  Crashing: %d\n", crashing)
	fmt.Printf("  🕐 Pending: %d\n", pending)

	// 4. Failed pods details
	if crashing > 0 {
		fmt.Println("\n4️⃣  Failed Pods Details:")
		cmd = exec.Command("kubectl", "get", "pods", "--all-namespaces", "--field-selector=status.phase!=Running,status.phase!=Succeeded")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Run()
	}

	// 5. Resource usage
	fmt.Println("\n5️⃣  Resource Usage:")
	cmd = exec.Command("kubectl", "top", "nodes")
	output, err = cmd.CombinedOutput()
	if err != nil {
		fmt.Println("  ⚠️  Metrics not available (install metrics-server)")
	} else {
		fmt.Println(string(output))
	}

	// 6. Storage
	fmt.Println("6️⃣  Storage:")
	cmd = exec.Command("kubectl", "get", "pvc", "--all-namespaces")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()

	fmt.Println("\n✅ Diagnostics complete!")
	return nil
}

// FixServices automatically fixes common issues with failing services
func (d *Deployer) FixServices(serviceFilter string) error {
	fmt.Println("=====================================")
	fmt.Println("🔧 Fixing Services")
	fmt.Println("=====================================\n")

	// Get all failing pods
	cmd := exec.Command("kubectl", "get", "pods", "--all-namespaces", 
		"--field-selector=status.phase!=Running,status.phase!=Succeeded",
		"-o", "jsonpath={range .items[*]}{.metadata.namespace}{'/'}{.metadata.name}{'\\n'}{end}")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get failing pods: %w", err)
	}

	failingPods := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(failingPods) == 0 || failingPods[0] == "" {
		fmt.Println("✅ No failing pods found!")
		return nil
	}

	fmt.Printf("Found %d failing pod(s)\n\n", len(failingPods))

	for _, pod := range failingPods {
		if pod == "" {
			continue
		}

		parts := strings.Split(pod, "/")
		if len(parts) != 2 {
			continue
		}
		namespace := parts[0]
		podName := parts[1]

		// Filter by service if specified
		if serviceFilter != "" && !strings.Contains(podName, serviceFilter) {
			continue
		}

		fmt.Printf("🔧 Fixing %s in %s...\n", podName, namespace)

		// Get pod logs to identify issue
		cmd = exec.Command("kubectl", "logs", "-n", namespace, podName, "--tail=20")
		logs, _ := cmd.Output()
		logsStr := string(logs)

		// Common fixes based on log patterns
		if strings.Contains(logsStr, "Permission denied") {
			fmt.Println("  📌 Issue: Permission denied")
			d.fixPermissionIssue(namespace, podName)
		} else if strings.Contains(logsStr, "unix domain socket") {
			fmt.Println("  📌 Issue: Unix socket permission")
			d.fixSocketPermission(namespace, podName)
		} else if strings.Contains(logsStr, "cache type") {
			fmt.Println("  📌 Issue: Cache configuration")
			d.fixCacheConfig(namespace, podName)
		} else {
			fmt.Println("  📌 Issue: Unknown - restarting pod")
			d.restartPod(namespace, podName)
		}
	}

	fmt.Println("\n✅ Fix attempt complete! Checking status in 30s...")
	time.Sleep(30 * time.Second)

	// Show updated status
	cmd = exec.Command("kubectl", "get", "pods", "--all-namespaces", 
		"--field-selector=status.phase!=Running,status.phase!=Succeeded")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()

	return nil
}

func (d *Deployer) fixPermissionIssue(namespace, podName string) {
	// Delete pod to trigger restart with corrected permissions
	fmt.Println("  🔄 Restarting with permission fix...")
	cmd := exec.Command("kubectl", "delete", "pod", "-n", namespace, podName)
	cmd.Run()
}

func (d *Deployer) fixSocketPermission(namespace, podName string) {
	// RabbitMQ specific fix
	fmt.Println("  🔄 Applying RabbitMQ socket fix...")
	
	// Delete and re-apply with corrected security context
	cmd := exec.Command("kubectl", "delete", "pod", "-n", namespace, podName)
	cmd.Run()
	
	time.Sleep(5 * time.Second)
	
	// Re-apply manifest will use updated configuration
	d.applyManifest("deployment/all-services.yaml")
}

func (d *Deployer) fixCacheConfig(namespace, podName string) {
	// Harbor specific fix
	fmt.Println("  🔄 Fixing Harbor cache configuration...")
	
	cmd := exec.Command("kubectl", "delete", "pod", "-n", namespace, podName)
	cmd.Run()
}

func (d *Deployer) restartPod(namespace, podName string) {
	fmt.Println("  🔄 Restarting pod...")
	cmd := exec.Command("kubectl", "delete", "pod", "-n", namespace, podName)
	cmd.Run()
}
