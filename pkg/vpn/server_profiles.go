package vpn

import (
	"fmt"
	"net"
	"os/exec"
	"sort"
	"strings"
)

// ServerPublicKey returns WireGuard server public key for wg0.
func ServerPublicKey() (string, error) {
	out, err := exec.Command("wg", "show", "wg0").Output()
	if err != nil {
		return "", fmt.Errorf("wg show wg0 failed: %w", err)
	}
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "public key:") {
			return strings.TrimSpace(strings.TrimPrefix(line, "public key:")), nil
		}
	}
	return "", fmt.Errorf("server public key not found in wg output")
}

// NextFreeClientIP picks next free 10.8.0.x/32 based on wg0 peers allowed-ips.
func NextFreeClientIP() (string, error) {
	out, err := exec.Command("wg", "show", "wg0", "allowed-ips").Output()
	if err != nil {
		// fallback: parse full output
		out, err = exec.Command("wg", "show", "wg0").Output()
		if err != nil {
			return "", fmt.Errorf("wg show wg0 failed: %w", err)
		}
	}

	used := map[string]bool{}
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		// Possible formats:
		// <peerKey>\t10.8.0.2/32
		// allowed ips: 10.8.0.2/32
		if strings.Contains(line, "allowed ips:") {
			line = strings.TrimSpace(strings.TrimPrefix(line, "allowed ips:"))
		}
		fields := strings.FieldsFunc(line, func(r rune) bool { return r == '\t' || r == ' ' || r == ',' })
		for _, f := range fields {
			if strings.Contains(f, "/") {
				ip := strings.SplitN(f, "/", 2)[0]
				if net.ParseIP(ip) != nil {
					used[ip] = true
				}
			}
		}
	}

	// Prefer 10.8.0.2..10.8.0.254
	for i := 2; i <= 254; i++ {
		ip := fmt.Sprintf("10.8.0.%d", i)
		if !used[ip] {
			return ip, nil
		}
	}
	return "", fmt.Errorf("no free client IPs in 10.8.0.0/24")
}

// CreateClientConfig returns a WireGuard client configuration and registers the peer on the server.
func CreateClientConfig(endpointHost string, endpointPort int, clientIP string) ([]byte, error) {
	if strings.TrimSpace(clientIP) == "" {
		next, err := NextFreeClientIP()
		if err != nil {
			return nil, err
		}
		clientIP = next
	}
	if endpointPort == 0 {
		endpointPort = 51820
	}

	serverPub, err := ServerPublicKey()
	if err != nil {
		return nil, err
	}

	priv, pub, err := generateKeysLocal()
	if err != nil {
		return nil, err
	}

	// Register peer
	if err := addPeer(pub, clientIP); err != nil {
		return nil, err
	}

	cfg := fmt.Sprintf(`[Interface]
PrivateKey = %s
Address = %s/24
DNS = 10.43.0.10

[Peer]
PublicKey = %s
Endpoint = %s:%d
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16
PersistentKeepalive = 25
`, priv, clientIP, serverPub, endpointHost, endpointPort)

	return []byte(cfg), nil
}

func generateKeysLocal() (privateKey, publicKey string, err error) {
	privOut, err := exec.Command("wg", "genkey").Output()
	if err != nil {
		return "", "", fmt.Errorf("wg genkey failed: %w", err)
	}
	privateKey = strings.TrimSpace(string(privOut))

	cmd := exec.Command("wg", "pubkey")
	cmd.Stdin = strings.NewReader(privateKey)
	pubOut, err := cmd.Output()
	if err != nil {
		return "", "", fmt.Errorf("wg pubkey failed: %w", err)
	}
	publicKey = strings.TrimSpace(string(pubOut))
	return privateKey, publicKey, nil
}

func addPeer(clientPublicKey, clientIP string) error {
	// wg set wg0 peer <key> allowed-ips <ip>/32
	cmd := exec.Command("wg", "set", "wg0", "peer", clientPublicKey, "allowed-ips", fmt.Sprintf("%s/32", clientIP))
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("wg set peer failed: %w\nOutput: %s", err, string(out))
	}
	// Persist into wg0.conf if possible (optional). Many setups use wg-quick.
	return nil
}

// SortedUsedIPs is a helper for debugging/ops.
func SortedUsedIPs() ([]string, error) {
	out, err := exec.Command("wg", "show", "wg0", "allowed-ips").Output()
	if err != nil {
		return nil, err
	}
	used := map[string]bool{}
	for _, line := range strings.Split(string(out), "\n") {
		fields := strings.Fields(line)
		for _, f := range fields {
			if strings.Contains(f, "/") {
				ip := strings.SplitN(f, "/", 2)[0]
				if net.ParseIP(ip) != nil {
					used[ip] = true
				}
			}
		}
	}
	var ips []string
	for ip := range used {
		ips = append(ips, ip)
	}
	sort.Strings(ips)
	return ips, nil
}
