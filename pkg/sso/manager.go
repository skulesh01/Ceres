package sso

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

type Manager struct{}

func NewManager() *Manager {
	return &Manager{}
}

// Install deploys Keycloak realm and OAuth2 Proxy
func (m *Manager) Install() error {
	fmt.Println("📋 Installing SSO components...")

	// 1. Wait for Keycloak to be ready
	fmt.Println("⏳ Waiting for Keycloak to be ready...")
	if err := m.waitForKeycloak(); err != nil {
		return fmt.Errorf("keycloak not ready: %w", err)
	}

	// 2. Import Keycloak realm
	fmt.Println("🔧 Importing Keycloak realm configuration...")
	if err := m.importRealm(); err != nil {
		return fmt.Errorf("failed to import realm: %w", err)
	}

	// 3. Deploy OAuth2 Proxy
	fmt.Println("🔐 Deploying OAuth2 Proxy...")
	cmd := exec.Command("kubectl", "apply", "-f", "/root/Ceres/deployment/oauth2-proxy.yaml")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed to deploy oauth2-proxy: %w\n%s", err, output)
	}

	// 4. Apply domain-based Ingress routes
	fmt.Println("🌐 Applying domain-based Ingress routes...")
	cmd = exec.Command("kubectl", "apply", "-f", "/root/Ceres/deployment/ingress-domains.yaml")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed to apply ingress routes: %w\n%s", err, output)
	}

	// 5. Get client secrets
	fmt.Println("🔑 Retrieving client secrets...")
	secrets, err := m.getClientSecrets()
	if err != nil {
		return fmt.Errorf("failed to get client secrets: %w", err)
	}

	fmt.Println("\n✅ SSO components installed successfully!")
	fmt.Println("\n📝 Client Secrets:")
	for client, secret := range secrets {
		fmt.Printf("   %s: %s\n", client, secret)
	}

	fmt.Println("\n🌐 Access URLs:")
	fmt.Println("   Keycloak Admin: https://keycloak.ceres.local")
	fmt.Println("   Username: admin")
	fmt.Println("   Password: K3yClo@k!2025")
	fmt.Println("\n💡 Add to /etc/hosts:")
	fmt.Println("   192.168.1.3 keycloak.ceres.local gitlab.ceres.local grafana.ceres.local")
	fmt.Println("   192.168.1.3 chat.ceres.local files.ceres.local wiki.ceres.local")
	fmt.Println("   192.168.1.3 mail.ceres.local portainer.ceres.local db.ceres.local")
	fmt.Println("   192.168.1.3 minio.ceres.local prometheus.ceres.local projects.ceres.local vault.ceres.local")

	return nil
}

// waitForKeycloak waits for Keycloak to be ready
func (m *Manager) waitForKeycloak() error {
	maxRetries := 60
	for i := 0; i < maxRetries; i++ {
		cmd := exec.Command("kubectl", "get", "pods", "-n", "ceres", "-l", "app=keycloak",
			"-o", "jsonpath={.items[0].status.phase}")
		output, err := cmd.CombinedOutput()
		if err == nil && strings.TrimSpace(string(output)) == "Running" {
			// Wait additional 30s for Keycloak to fully initialize
			fmt.Println("   ✓ Keycloak pod running, waiting for initialization...")
			time.Sleep(30 * time.Second)
			return nil
		}
		fmt.Printf("   Waiting... (%d/%d)\n", i+1, maxRetries)
		time.Sleep(5 * time.Second)
	}
	return fmt.Errorf("keycloak did not become ready in time")
}

// importRealm imports the CERES realm into Keycloak
func (m *Manager) importRealm() error {
	// Copy realm config to Keycloak pod
	podName, err := m.getKeycloakPod()
	if err != nil {
		return err
	}

	// Copy realm file
	cmd := exec.Command("kubectl", "cp",
		"/root/Ceres/config/keycloak-realm.json",
		fmt.Sprintf("ceres/%s:/tmp/realm.json", podName))
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed to copy realm file: %w\n%s", err, output)
	}

	// Import via Keycloak CLI
	importCmd := fmt.Sprintf(
		"/opt/keycloak/bin/kc.sh import --file /tmp/realm.json --override true")

	cmd = exec.Command("kubectl", "exec", "-n", "ceres", podName, "--",
		"bash", "-c", importCmd)
	output, err := cmd.CombinedOutput()
	if err != nil {
		// Fallback: import via REST API
		return m.importRealmViaAPI()
	}

	fmt.Printf("   ✓ Realm imported: %s\n", string(output))
	return nil
}

// importRealmViaAPI imports realm using Keycloak Admin REST API
func (m *Manager) importRealmViaAPI() error {
	fmt.Println("   Falling back to REST API import...")

	// Get admin token
	token, err := m.getAdminToken()
	if err != nil {
		return err
	}

	// Read realm file
	realmData, err := os.ReadFile("/root/Ceres/config/keycloak-realm.json")
	if err != nil {
		return fmt.Errorf("failed to read realm file: %w", err)
	}

	// Import realm
	podName, err := m.getKeycloakPod()
	if err != nil {
		return err
	}

	curlCmd := fmt.Sprintf(`curl -X POST http://localhost:8080/admin/realms \
		-H "Authorization: Bearer %s" \
		-H "Content-Type: application/json" \
		-d '%s'`, token, string(realmData))

	cmd := exec.Command("kubectl", "exec", "-n", "ceres", podName, "--",
		"bash", "-c", curlCmd)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to import realm via API: %w\n%s", err, output)
	}

	fmt.Println("   ✓ Realm imported via API")
	return nil
}

// getAdminToken retrieves Keycloak admin access token
func (m *Manager) getAdminToken() (string, error) {
	podName, err := m.getKeycloakPod()
	if err != nil {
		return "", err
	}

	curlCmd := `curl -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-d "username=admin" \
		-d "password=K3yClo@k!2025" \
		-d "grant_type=password" \
		-d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4`

	cmd := exec.Command("kubectl", "exec", "-n", "ceres", podName, "--",
		"bash", "-c", curlCmd)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to get admin token: %w\n%s", err, output)
	}

	return strings.TrimSpace(string(output)), nil
}

// getClientSecrets retrieves client secrets from Keycloak
func (m *Manager) getClientSecrets() (map[string]string, error) {
	token, err := m.getAdminToken()
	if err != nil {
		return nil, err
	}

	podName, err := m.getKeycloakPod()
	if err != nil {
		return nil, err
	}

	clients := []string{"gitlab", "grafana", "mattermost", "wikijs", "nextcloud", "oauth2-proxy"}
	secrets := make(map[string]string)

	for _, client := range clients {
		// Get client ID (UUID)
		getClientCmd := fmt.Sprintf(`curl -s http://localhost:8080/admin/realms/ceres/clients \
			-H "Authorization: Bearer %s" | grep -o '"id":"[^"]*","clientId":"%s"' | grep -o '"id":"[^"]*"' | cut -d'"' -f4`,
			token, client)

		cmd := exec.Command("kubectl", "exec", "-n", "ceres", podName, "--",
			"bash", "-c", getClientCmd)
		clientID, err := cmd.CombinedOutput()
		if err != nil {
			secrets[client] = "ERROR: Could not retrieve"
			continue
		}

		// Get client secret
		getSecretCmd := fmt.Sprintf(`curl -s http://localhost:8080/admin/realms/ceres/clients/%s/client-secret \
			-H "Authorization: Bearer %s" | grep -o '"value":"[^"]*"' | cut -d'"' -f4`,
			strings.TrimSpace(string(clientID)), token)

		cmd = exec.Command("kubectl", "exec", "-n", "ceres", podName, "--",
			"bash", "-c", getSecretCmd)
		secret, err := cmd.CombinedOutput()
		if err != nil {
			secrets[client] = "ERROR: Could not retrieve"
			continue
		}

		secrets[client] = strings.TrimSpace(string(secret))
	}

	return secrets, nil
}

// getKeycloakPod returns the Keycloak pod name
func (m *Manager) getKeycloakPod() (string, error) {
	cmd := exec.Command("kubectl", "get", "pods", "-n", "ceres", "-l", "app=keycloak",
		"-o", "jsonpath={.items[0].metadata.name}")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to get keycloak pod: %w", err)
	}
	return strings.TrimSpace(string(output)), nil
}

// IntegrateService integrates a specific service with SSO
func (m *Manager) IntegrateService(service string) error {
	fmt.Printf("🔧 Integrating %s with SSO...\n", service)

	switch service {
	case "gitlab":
		return m.integrateGitLab()
	case "grafana":
		return m.integrateGrafana()
	case "mattermost":
		return m.integrateMattermost()
	case "wikijs":
		return m.integrateWikiJS()
	case "nextcloud":
		return m.integrateNextcloud()
	case "mailcow", "portainer", "adminer", "minio", "prometheus":
		return m.integrateViaOAuth2Proxy(service)
	default:
		return fmt.Errorf("unknown service: %s", service)
	}
}

// integrateGitLab configures GitLab OIDC
func (m *Manager) integrateGitLab() error {
	// Get client secret
	secrets, err := m.getClientSecrets()
	if err != nil {
		return err
	}

	secret := secrets["gitlab"]
	if secret == "" || strings.HasPrefix(secret, "ERROR") {
		return fmt.Errorf("could not retrieve GitLab client secret")
	}

	fmt.Println("   ✓ Client secret retrieved")
	fmt.Println("\n   📝 Manual steps required:")
	fmt.Println("   1. Edit GitLab configuration:")
	fmt.Println("      kubectl edit configmap gitlab-config -n gitlab")
	fmt.Println("   2. Add OIDC configuration (see config/sso-configs.yaml)")
	fmt.Printf("   3. Use client secret: %s\n", secret)
	fmt.Println("   4. Restart GitLab:")
	fmt.Println("      kubectl rollout restart deployment/gitlab -n gitlab")

	return nil
}

// integrateGrafana configures Grafana OIDC
func (m *Manager) integrateGrafana() error {
	secrets, err := m.getClientSecrets()
	if err != nil {
		return err
	}

	secret := secrets["grafana"]
	if secret == "" || strings.HasPrefix(secret, "ERROR") {
		return fmt.Errorf("could not retrieve Grafana client secret")
	}

	fmt.Println("   ✓ Client secret retrieved")
	fmt.Println("\n   📝 Manual steps required:")
	fmt.Println("   1. Edit Grafana configuration:")
	fmt.Println("      kubectl edit configmap grafana-config -n monitoring")
	fmt.Println("   2. Add OAuth configuration (see config/sso-configs.yaml)")
	fmt.Printf("   3. Use client secret: %s\n", secret)
	fmt.Println("   4. Restart Grafana:")
	fmt.Println("      kubectl rollout restart deployment/grafana -n monitoring")

	return nil
}

// integrateMattermost configures Mattermost OIDC
func (m *Manager) integrateMattermost() error {
	secrets, err := m.getClientSecrets()
	if err != nil {
		return err
	}

	secret := secrets["mattermost"]
	if secret == "" || strings.HasPrefix(secret, "ERROR") {
		return fmt.Errorf("could not retrieve Mattermost client secret")
	}

	fmt.Println("   ✓ Client secret retrieved")
	fmt.Println("\n   📝 Manual steps required:")
	fmt.Println("   1. Login to Mattermost as admin")
	fmt.Println("   2. Go to System Console > Authentication > GitLab")
	fmt.Println("   3. Configure:")
	fmt.Println("      Enable: true")
	fmt.Printf("      Client ID: mattermost\n")
	fmt.Printf("      Client Secret: %s\n", secret)
	fmt.Println("      Auth Endpoint: https://keycloak.ceres.local/realms/ceres/protocol/openid-connect/auth")
	fmt.Println("      Token Endpoint: https://keycloak.ceres.local/realms/ceres/protocol/openid-connect/token")
	fmt.Println("      User API Endpoint: https://keycloak.ceres.local/realms/ceres/protocol/openid-connect/userinfo")

	return nil
}

// integrateWikiJS configures Wiki.js OIDC
func (m *Manager) integrateWikiJS() error {
	secrets, err := m.getClientSecrets()
	if err != nil {
		return err
	}

	secret := secrets["wikijs"]
	if secret == "" || strings.HasPrefix(secret, "ERROR") {
		return fmt.Errorf("could not retrieve Wiki.js client secret")
	}

	fmt.Println("   ✓ Client secret retrieved")
	fmt.Println("\n   📝 Manual steps required:")
	fmt.Println("   1. Login to Wiki.js as admin")
	fmt.Println("   2. Go to Administration > Authentication > OpenID Connect")
	fmt.Println("   3. Configure:")
	fmt.Printf("      Client ID: wikijs\n")
	fmt.Printf("      Client Secret: %s\n", secret)
	fmt.Println("      Authorization Endpoint: https://keycloak.ceres.local/realms/ceres/protocol/openid-connect/auth")
	fmt.Println("      Token Endpoint: https://keycloak.ceres.local/realms/ceres/protocol/openid-connect/token")
	fmt.Println("      User Info Endpoint: https://keycloak.ceres.local/realms/ceres/protocol/openid-connect/userinfo")
	fmt.Println("      Issuer: https://keycloak.ceres.local/realms/ceres")

	return nil
}

// integrateNextcloud configures Nextcloud OIDC
func (m *Manager) integrateNextcloud() error {
	secrets, err := m.getClientSecrets()
	if err != nil {
		return err
	}

	secret := secrets["nextcloud"]
	if secret == "" || strings.HasPrefix(secret, "ERROR") {
		return fmt.Errorf("could not retrieve Nextcloud client secret")
	}

	fmt.Println("   ✓ Client secret retrieved")
	fmt.Println("\n   📝 Automatic configuration...")

	// Install OIDC app
	podName, err := m.getNextcloudPod()
	if err != nil {
		return err
	}

	cmd := exec.Command("kubectl", "exec", "-n", "nextcloud", podName, "--",
		"su", "-s", "/bin/bash", "www-data", "-c", "php occ app:install user_oidc")
	output, _ := cmd.CombinedOutput()
	fmt.Printf("   %s\n", string(output))

	// Configure OIDC
	configCmd := fmt.Sprintf(`php occ config:app:set user_oidc provider_url --value="https://keycloak.ceres.local/realms/ceres" && \
		php occ config:app:set user_oidc client_id --value="nextcloud" && \
		php occ config:app:set user_oidc client_secret --value="%s"`, secret)

	cmd = exec.Command("kubectl", "exec", "-n", "nextcloud", podName, "--",
		"su", "-s", "/bin/bash", "www-data", "-c", configCmd)
	output, err = cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to configure OIDC: %w\n%s", err, output)
	}

	fmt.Println("   ✓ Nextcloud OIDC configured automatically")
	return nil
}

// integrateViaOAuth2Proxy configures service to use OAuth2 Proxy
func (m *Manager) integrateViaOAuth2Proxy(service string) error {
	fmt.Printf("   ✓ %s will be protected by OAuth2 Proxy\n", service)
	fmt.Println("   No additional configuration required - access via domain name")
	return nil
}

// getNextcloudPod returns the Nextcloud pod name
func (m *Manager) getNextcloudPod() (string, error) {
	cmd := exec.Command("kubectl", "get", "pods", "-n", "nextcloud", "-l", "app=nextcloud",
		"-o", "jsonpath={.items[0].metadata.name}")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to get nextcloud pod: %w", err)
	}
	return strings.TrimSpace(string(output)), nil
}

// IntegrateAll integrates all supported services with SSO
func (m *Manager) IntegrateAll() error {
	services := []string{
		"gitlab", "grafana", "mattermost", "wikijs", "nextcloud",
		"mailcow", "portainer", "adminer", "minio", "prometheus",
	}

	fmt.Println("🔧 Integrating all services with SSO...")
	for _, service := range services {
		if err := m.IntegrateService(service); err != nil {
			fmt.Printf("   ⚠️  %s: %v\n", service, err)
		}
	}

	fmt.Println("\n✅ SSO integration complete!")
	return nil
}

// CreateClient creates a new Keycloak client
func (m *Manager) CreateClient(clientName, redirectURI string) error {
	token, err := m.getAdminToken()
	if err != nil {
		return err
	}

	podName, err := m.getKeycloakPod()
	if err != nil {
		return err
	}

	clientConfig := map[string]interface{}{
		"clientId":                  clientName,
		"enabled":                   true,
		"protocol":                  "openid-connect",
		"publicClient":              false,
		"redirectUris":              []string{redirectURI},
		"standardFlowEnabled":       true,
		"implicitFlowEnabled":       false,
		"directAccessGrantsEnabled": true,
	}

	jsonData, err := json.Marshal(clientConfig)
	if err != nil {
		return err
	}

	curlCmd := fmt.Sprintf(`curl -X POST http://localhost:8080/admin/realms/ceres/clients \
		-H "Authorization: Bearer %s" \
		-H "Content-Type: application/json" \
		-d '%s'`, token, string(jsonData))

	cmd := exec.Command("kubectl", "exec", "-n", "ceres", podName, "--",
		"bash", "-c", curlCmd)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to create client: %w\n%s", err, output)
	}

	fmt.Printf("✅ Client '%s' created successfully\n", clientName)
	return nil
}

// Status checks SSO component status
func (m *Manager) Status() error {
	fmt.Println("🔍 Checking SSO status...")

	// Check Keycloak
	cmd := exec.Command("kubectl", "get", "pods", "-n", "ceres", "-l", "app=keycloak")
	output, _ := cmd.CombinedOutput()
	fmt.Println("\n🔐 Keycloak:")
	fmt.Println(string(output))

	// Check OAuth2 Proxy
	cmd = exec.Command("kubectl", "get", "pods", "-n", "oauth2-proxy")
	output, _ = cmd.CombinedOutput()
	fmt.Println("\n🔒 OAuth2 Proxy:")
	fmt.Println(string(output))

	// Check Ingress routes
	cmd = exec.Command("kubectl", "get", "ingress", "--all-namespaces")
	output, _ = cmd.CombinedOutput()
	fmt.Println("\n🌐 Ingress Routes:")
	fmt.Println(string(output))

	return nil
}
