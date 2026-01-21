package vpn

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// VPNManager manages WireGuard VPN configuration
type VPNManager struct {
	serverIP    string
	serverPort  string
	vpnNetwork  string
	configPath  string
}

// NewVPNManager creates VPN manager
func NewVPNManager(serverIP string) *VPNManager {
	return &VPNManager{
		serverIP:   serverIP,
		serverPort: "51820",
		vpnNetwork: "10.8.0.0/24",
	}
}

// Setup configures WireGuard VPN client
func (v *VPNManager) Setup() error {
	fmt.Println("\n🔐 Setting up WireGuard VPN...")

	// Check if WireGuard is installed
	if !v.isInstalled() {
		return v.install()
	}

	// Get server public key
	publicKey, err := v.getServerPublicKey()
	if err != nil {
		return fmt.Errorf("failed to get server public key: %w", err)
	}

	// Generate client keys
	privateKey, clientPublicKey, err := v.generateClientKeys()
	if err != nil {
		return fmt.Errorf("failed to generate client keys: %w", err)
	}

	// Create client config
	if err := v.createClientConfig(privateKey, publicKey); err != nil {
		return fmt.Errorf("failed to create client config: %w", err)
	}

	// Add client to server
	if err := v.addClientToServer(clientPublicKey); err != nil {
		return fmt.Errorf("failed to add client to server: %w", err)
	}

	// Connect
	if err := v.connect(); err != nil {
		return fmt.Errorf("failed to connect: %w", err)
	}

	fmt.Println("✅ VPN setup complete!")
	fmt.Printf("📍 VPN IP: 10.8.0.2\n")
	fmt.Printf("🌐 Access services via ClusterIP directly\n")
	return nil
}

// isInstalled checks if WireGuard is installed
func (v *VPNManager) isInstalled() bool {
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command("where", "wireguard")
	} else {
		cmd = exec.Command("which", "wg")
	}
	return cmd.Run() == nil
}

// install installs WireGuard
func (v *VPNManager) install() error {
	fmt.Println("📦 Installing WireGuard...")
	
	switch runtime.GOOS {
	case "windows":
		fmt.Println("Please install WireGuard from: https://www.wireguard.com/install/")
		fmt.Println("After installation, run this command again.")
		return fmt.Errorf("WireGuard not installed")
	case "linux":
		cmd := exec.Command("sudo", "apt-get", "install", "-y", "wireguard")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()
	case "darwin":
		cmd := exec.Command("brew", "install", "wireguard-tools")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()
	default:
		return fmt.Errorf("unsupported OS: %s", runtime.GOOS)
	}
}

// getServerPublicKey retrieves server public key via SSH
func (v *VPNManager) getServerPublicKey() (string, error) {
	cmd := exec.Command("ssh", fmt.Sprintf("root@%s", v.serverIP),
		"cat", "/etc/wireguard/publickey")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// generateClientKeys generates WireGuard keys for client
func (v *VPNManager) generateClientKeys() (privateKey, publicKey string, err error) {
	// Generate private key
	cmd := exec.Command("wg", "genkey")
	privOut, err := cmd.Output()
	if err != nil {
		return "", "", err
	}
	privateKey = strings.TrimSpace(string(privOut))

	// Generate public key from private
	cmd = exec.Command("wg", "pubkey")
	cmd.Stdin = strings.NewReader(privateKey)
	pubOut, err := cmd.Output()
	if err != nil {
		return "", "", err
	}
	publicKey = strings.TrimSpace(string(pubOut))

	return privateKey, publicKey, nil
}

// createClientConfig creates WireGuard client configuration
func (v *VPNManager) createClientConfig(privateKey, serverPublicKey string) error {
	config := fmt.Sprintf(`[Interface]
PrivateKey = %s
Address = 10.8.0.2/24
DNS = 10.43.0.10

[Peer]
PublicKey = %s
Endpoint = %s:%s
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16
PersistentKeepalive = 25
`, privateKey, serverPublicKey, v.serverIP, v.serverPort)

	// Determine config path
	if runtime.GOOS == "windows" {
		v.configPath = filepath.Join(os.Getenv("PROGRAMFILES"), "WireGuard", "Data", "Configurations", "ceres.conf")
	} else {
		v.configPath = "/etc/wireguard/ceres.conf"
	}

	// Write config
	if err := os.MkdirAll(filepath.Dir(v.configPath), 0755); err != nil {
		return err
	}
	return os.WriteFile(v.configPath, []byte(config), 0600)
}

// addClientToServer adds client public key to server
func (v *VPNManager) addClientToServer(clientPublicKey string) error {
	cmd := exec.Command("ssh", fmt.Sprintf("root@%s", v.serverIP),
		"wg", "set", "wg0", "peer", clientPublicKey,
		"allowed-ips", "10.8.0.2/32")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// connect starts WireGuard connection
func (v *VPNManager) connect() error {
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command("wireguard", "/installtunnelservice", v.configPath)
	} else {
		cmd = exec.Command("sudo", "wg-quick", "up", "ceres")
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// Disconnect stops VPN connection
func (v *VPNManager) Disconnect() error {
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command("wireguard", "/uninstalltunnelservice", "ceres")
	} else {
		cmd = exec.Command("sudo", "wg-quick", "down", "ceres")
	}
	return cmd.Run()
}

// Status checks VPN connection status
func (v *VPNManager) Status() (string, error) {
	cmd := exec.Command("wg", "show")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(output), nil
}
