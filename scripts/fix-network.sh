#!/usr/bin/env bash
# Fix network DNS issues on server

set -e

echo "[NETWORK] Checking network configuration..."

# Проверяем интернет доступ
if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    echo "[OK] Internet connectivity works (IP level)"
else
    echo "[ERROR] No internet connectivity!"
    echo "Please check network configuration in Proxmox"
    exit 1
fi

# Проверяем DNS
if nslookup github.com &>/dev/null; then
    echo "[OK] DNS resolution works"
    exit 0
fi

echo "[WARN] DNS resolution not working, fixing..."

# Бэкапим текущий resolv.conf
cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true

# Пробуем разные DNS серверы
DNS_SERVERS=(
    "8.8.8.8"       # Google Public DNS
    "8.8.4.4"       # Google Public DNS
    "1.1.1.1"       # Cloudflare DNS
    "192.168.1.1"   # Local gateway (often has DNS)
)

# Проверяем какой DNS работает
WORKING_DNS=""
for dns in "${DNS_SERVERS[@]}"; do
    echo "Testing DNS server: $dns"
    if timeout 3 nslookup github.com "$dns" &>/dev/null; then
        WORKING_DNS="$dns"
        echo "[OK] DNS server $dns works!"
        break
    fi
done

if [ -z "$WORKING_DNS" ]; then
    echo "[ERROR] No working DNS server found!"
    echo "Trying to use systemd-resolved..."
    
    # Пробуем через systemd-resolved
    if systemctl is-active --quiet systemd-resolved; then
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
        systemctl restart systemd-resolved
    else
        # Устанавливаем Google DNS как fallback
        cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 192.168.1.1
EOF
    fi
else
    # Настраиваем рабочий DNS
    cat > /etc/resolv.conf << EOF
nameserver $WORKING_DNS
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
fi

# Делаем resolv.conf иммутабельным (предотвращаем перезапись)
chattr +i /etc/resolv.conf 2>/dev/null || true

# Финальный тест
echo ""
echo "[TEST] Final DNS test..."
if nslookup github.com; then
    echo ""
    echo "[SUCCESS] DNS fixed! github.com resolves correctly"
    exit 0
else
    echo ""
    echo "[ERROR] DNS still not working. Manual intervention required."
    echo ""
    echo "Try manually:"
    echo "  1. Check firewall: ufw status"
    echo "  2. Check routes: ip route"
    echo "  3. Check gateway: ping 192.168.1.1"
    echo "  4. Edit /etc/resolv.conf manually"
    exit 1
fi
