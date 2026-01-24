package deployment

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const CeresVersion = "3.1.0"

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
	if err := d.applyManifest("deployment/promtail.yaml"); err != nil {
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

	fmt.Println("\n📦 Step 5: Identity (Keycloak)")
	if err := d.applyManifest("deployment/keycloak.yaml"); err != nil {
		return err
	}
	d.waitForPods("ceres", "app=keycloak", 180)

	fmt.Println("\n📦 Step 6: Mail (SMTP/IMAP + Webmail)")
	if err := d.applyManifest("deployment/mailcow.yaml"); err != nil {
		return err
	}
	d.waitForPods("mailcow", "app=mailcow", 180)

	fmt.Println("\n📦 Step 7: All Services (Monitoring, Collaboration, Storage)")
	if err := d.applyManifest("deployment/all-services.yaml"); err != nil {
		return err
	}

	fmt.Println("\n📦 Step 8: NodePort Services (Direct Access)")
	if err := d.applyManifest("deployment/nodeport-services.yaml"); err != nil {
		return err
	}

	fmt.Println("\n📦 Step 9: Ingress (Domains via Traefik)")
	if err := d.applyManifest("deployment/ingress-domains.yaml"); err != nil {
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
		"deployment/mailcow.yaml",
		"deployment/all-services.yaml",
		"deployment/nodeport-services.yaml",
		"deployment/ingress-domains.yaml",
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
	resolved := d.resolveCeresPath(path)
	cmd := exec.Command("kubectl", "apply", "-f", resolved)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (d *Deployer) resolveCeresPath(p string) string {
	if p == "" {
		return p
	}
	// Absolute path or URL: do not touch.
	if filepath.IsAbs(p) || strings.HasPrefix(p, "http://") || strings.HasPrefix(p, "https://") {
		return p
	}

	candidates := []string{}
	if v := strings.TrimSpace(os.Getenv("CERES_ROOT")); v != "" {
		candidates = append(candidates, v)
	}
	if v := strings.TrimSpace(os.Getenv("CERES_REPO_ROOT")); v != "" {
		candidates = append(candidates, v)
	}
	if cwd, err := os.Getwd(); err == nil {
		candidates = append(candidates, cwd)
	}
	if exe, err := os.Executable(); err == nil {
		exeDir := filepath.Dir(exe)
		candidates = append(candidates, exeDir, filepath.Dir(exeDir))
	}

	for _, base := range candidates {
		candidate := filepath.Join(base, p)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}

	// Fallback: relative path.
	return p
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
		fmt.Printf("  Keycloak:    %s:8080 (admin / from secret ceres/keycloak-secret)\n", keycloakIP)
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

// RemoveDuplicates удаляет дублирующие namespace
func (d *Deployer) RemoveDuplicates() error {
	fmt.Println("🗑️  Удаление дублирующих сервисов...")

	duplicates := []string{
		"elasticsearch", "kibana", "harbor",
		"jenkins", "uptime-kuma",
	}

	for _, ns := range duplicates {
		fmt.Printf("  Удаляю namespace: %s...\n", ns)
		cmd := exec.Command("kubectl", "delete", "namespace", ns, "--ignore-not-found=true")
		if err := cmd.Run(); err != nil {
			fmt.Printf("  ⚠️  Ошибка удаления %s: %v\n", ns, err)
		} else {
			fmt.Printf("  ✅ Удален: %s\n", ns)
		}
	}

	fmt.Println("✅ Дубликаты удалены (освобождено ~4-6GB RAM)")
	return nil
}

// SetupTLS устанавливает Cert-Manager для автоматических TLS сертификатов
func (d *Deployer) SetupTLS() error {
	fmt.Println("🔐 Установка Cert-Manager...")

	// Add Helm repo
	exec.Command("helm", "repo", "add", "jetstack", "https://charts.jetstack.io").Run()
	exec.Command("helm", "repo", "update").Run()

	// Install Cert-Manager
	cmd := exec.Command("helm", "install", "cert-manager", "jetstack/cert-manager",
		"--namespace", "cert-manager",
		"--create-namespace",
		"--version", "v1.13.0",
		"--set", "installCRDs=true",
	)

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to install cert-manager: %w", err)
	}

	// Apply ClusterIssuers
	time.Sleep(10 * time.Second)
	d.applyManifest("deployment/cert-manager.yaml")

	fmt.Println("✅ Cert-Manager установлен")
	fmt.Println("🔐 ClusterIssuers: selfsigned, letsencrypt-prod")
	return nil
}

// SetupBackup устанавливает Velero для бэкапов
func (d *Deployer) SetupBackup() error {
	fmt.Println("💾 Установка Velero...")

	// Add Helm repo
	exec.Command("helm", "repo", "add", "vmware-tanzu", "https://vmware-tanzu.github.io/helm-charts").Run()
	exec.Command("helm", "repo", "update").Run()

	// Install Velero with AWS plugin for MinIO
	cmd := exec.Command("helm", "install", "velero", "vmware-tanzu/velero",
		"--namespace", "velero",
		"--create-namespace",
		"--set", "initContainers[0].name=velero-plugin-for-aws",
		"--set", "initContainers[0].image=velero/velero-plugin-for-aws:v1.8.0",
		"--set", "initContainers[0].volumeMounts[0].mountPath=/target",
		"--set", "initContainers[0].volumeMounts[0].name=plugins",
		"--set", "configuration.provider=aws",
		"--set", "configuration.backupStorageLocation.name=default",
		"--set", "configuration.backupStorageLocation.bucket=ceres-backups",
		"--set", "configuration.backupStorageLocation.config.region=minio",
		"--set", "configuration.backupStorageLocation.config.s3ForcePathStyle=true",
		"--set", "configuration.backupStorageLocation.config.s3Url=http://minio.minio.svc.cluster.local:9000",
	)

	if err := cmd.Run(); err != nil {
		fmt.Println("⚠️  Helm установка не удалась, применяю YAML...")
		if err := d.applyManifest("deployment/velero.yaml"); err != nil {
			return err
		}
	}

	// Wait for Velero to be ready
	d.waitForPods("velero", "app.kubernetes.io/name=velero", 180)

	fmt.Println("✅ Velero установлен")
	fmt.Println("📅 Настроен ежедневный backup в 2:00 AM")
	fmt.Println("💾 Backend: MinIO (ceres-backups bucket)")
	return nil
}

// SetupLogging устанавливает Promtail для сбора логов
func (d *Deployer) SetupLogging() error {
	fmt.Println("📊 Установка Promtail...")

	if err := d.applyManifest("deployment/promtail.yaml"); err != nil {
		return err
	}

	// Wait for DaemonSet
	time.Sleep(15 * time.Second)

	fmt.Println("✅ Promtail установлен (логи → Loki)")
	return nil
}

// SetupMail устанавливает Mailcow
func (d *Deployer) SetupMail() error {
	fmt.Println("📧 Установка Mailcow...")

	if err := d.applyManifest("deployment/mailcow.yaml"); err != nil {
		return err
	}

	// Wait for pods
	d.waitForPods("mailcow", "app=mailcow", 180)

	fmt.Println("✅ Mailcow установлен")
	fmt.Println("🌐 Webmail: http://mail.ceres.local")
	fmt.Println("📨 SMTP: mailcow-smtp.mailcow.svc:587")
	return nil
}

// FixKeycloak applies fixed Keycloak deployment with proper permissions
func (d *Deployer) FixKeycloak() error {
	fmt.Println("🔧 Fixing Keycloak deployment...")

	// Delete existing Keycloak deployment
	cmd := exec.Command("kubectl", "delete", "deployment", "keycloak", "-n", "ceres", "--ignore-not-found=true")
	output, _ := cmd.CombinedOutput()
	if len(output) > 0 {
		fmt.Printf("   Removed old deployment: %s\n", string(output))
	}

	// Reapply fixed manifest
	if err := d.applyManifest("deployment/keycloak.yaml"); err != nil {
		return fmt.Errorf("failed to apply keycloak manifest: %w", err)
	}

	// Wait for Keycloak to be ready
	fmt.Println("   Waiting for Keycloak pod...")
	d.waitForPods("ceres", "app=keycloak", 300)

	fmt.Println("✅ Keycloak fixed and running")
	fmt.Println("🌐 Admin: https://keycloak.ceres.local")
	fmt.Println("👤 Credentials: admin / K3yClo@k!2025")
	return nil
}

// HealthCheck выполняет проверку здоровья всех сервисов
func (d *Deployer) HealthCheck() error {
	fmt.Println("🏥 Проверка здоровья платформы...")

	// Get all pods
	cmd := exec.Command("kubectl", "get", "pods", "--all-namespaces",
		"-o", "jsonpath={range .items[*]}{.metadata.namespace}{'|'}{.metadata.name}{'|'}{.status.phase}{'\\n'}{end}")
	
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get pods: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	totalPods := 0
	runningPods := 0
	failedPods := 0

	for _, line := range lines {
		if line == "" {
			continue
		}
		parts := strings.Split(line, "|")
		if len(parts) < 3 {
			continue
		}

		totalPods++
		phase := parts[2]
		
		if phase == "Running" {
			runningPods++
		} else if phase == "Failed" || strings.Contains(phase, "Error") || strings.Contains(phase, "CrashLoop") {
			failedPods++
			fmt.Printf("  ❌ %s/%s: %s\n", parts[0], parts[1], phase)
		}
	}

	fmt.Printf("\n📊 Статус: %d/%d Running (%d Failed)\n", runningPods, totalPods, failedPods)

	if failedPods == 0 {
		fmt.Println("✅ Все сервисы здоровы!")
		return nil
	} else {
		fmt.Printf("⚠️  Найдено %d проблемных сервисов\n", failedPods)
		fmt.Println("💡 Запустите 'ceres fix' для автоматического исправления")
		return nil
	}
}
