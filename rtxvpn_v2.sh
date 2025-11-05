#!/bin/bash
# RTX-VPN Tunnel Installer with Edge and Auto UUID

GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
GOLD=$(tput setaf 3)
CYAN=$(tput setaf 6)
NC=$(tput sgr0)

root_check() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as ${RED}root!${NC}"
        exit 1
    fi
}

install_check() {
    if [ -d "/opt/rtxvpn_v2/tunnel" ]; then
        echo "RTX-VPN Tunnel is already ${GREEN}installed!${NC}"
        exit 1
    fi
}

uninstall() {
    if [ -d "/opt/rtxvpn_v2/tunnel" ]; then
        echo "Removing RTX-VPN Tunnel..."
        rm -rf /opt/rtxvpn_v2/tunnel
        systemctl stop rtxvpn.service 2>/dev/null
        systemctl disable rtxvpn.service 2>/dev/null
        rm -f /etc/systemd/system/rtxvpn.service 2>/dev/null
        echo "${GREEN}Tunnel removed!${NC}"
    else
        echo "RTX-VPN Tunnel is ${RED}not installed!${NC}"
    fi
}

download_tunnel_files() {
    apt update && apt install -y wget unzip python3 iptables iproute2 curl

    mkdir -p /opt/rtxvpn_v2/tunnel

    CPU_ARCH=$(uname -m)
    case $CPU_ARCH in
        x86_64)
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-amd64.zip
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
            unzip /opt/rtxvpn_v2/tunnel/rathole-x86_64-unknown-linux-gnu.zip -d /opt/rtxvpn_v2/tunnel/
            unzip /opt/rtxvpn_v2/tunnel/tun2socks-linux-amd64.zip -d /opt/rtxvpn_v2/tunnel/
            unzip /opt/rtxvpn_v2/tunnel/Xray-linux-64.zip -d /opt/rtxvpn_v2/tunnel/
            mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-amd64 /opt/rtxvpn_v2/tunnel/tun2socks
            chmod -R +x /opt/rtxvpn_v2/tunnel/
            ;;
        aarch64)
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-arm64.zip
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
            unzip /opt/rtxvpn_v2/tunnel/rathole-aarch64-unknown-linux-musl.zip -d /opt/rtxvpn_v2/tunnel/
            unzip /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64.zip -d /opt/rtxvpn_v2/tunnel/
            unzip /opt/rtxvpn_v2/tunnel/Xray-linux-arm64-v8a.zip -d /opt/rtxvpn_v2/tunnel/
            mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64 /opt/rtxvpn_v2/tunnel/tun2socks
            chmod -R +x /opt/rtxvpn_v2/tunnel/
            ;;
        *)
            echo "${RED}Unsupported CPU architecture: $CPU_ARCH${NC}"
            exit 1
            ;;
    esac

    # Download configs
    wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.json
    wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.toml
    wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.py
    wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.json
    wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.toml
}

generate_uuid() {
    # Requires uuidgen
    command -v uuidgen >/dev/null 2>&1 || apt install -y uuid-runtime
    UUID=$(uuidgen)
    echo "Generated UUID: $UUID"
    sed -i "s/\"uuid\"/\"$UUID\"/g" /opt/rtxvpn_v2/tunnel/tunnel.json
    sed -i "s/\"uuid\"/\"$UUID\"/g" /opt/rtxvpn_v2/tunnel/tunnel.toml
}

tunnel_setup() {
    read -p "Enter TUN interface name (default: rtx): " TUN_INTERFACE
    TUN_INTERFACE=${TUN_INTERFACE:-rtx}
    read -p "Enter client IP range (CIDR) for VPN clients (e.g., 192.192.192.0/24): " CLIENT_RANGE
    read -p "Do you want to enable Edge (connect to remote server)? (y/n): " ENABLE_EDGE
    ENABLE_EDGE=$(echo "$ENABLE_EDGE" | tr '[:upper:]' '[:lower:]')

    # Setup TUN interface
    ip link show $TUN_INTERFACE >/dev/null 2>&1 || ip tuntap add mode tun dev $TUN_INTERFACE
    ip link set dev $TUN_INTERFACE up

    # Routing table
    grep -q "100 rtx_table" /etc/iproute2/rt_tables || echo "100 rtx_table" >> /etc/iproute2/rt_tables
    ip route add default dev $TUN_INTERFACE table rtx_table
    ip route add $CLIENT_RANGE dev wg0 table rtx_table
    ip rule add from $CLIENT_RANGE table rtx_table priority 100

    # iptables
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -A FORWARD -i wg0 -o $TUN_INTERFACE -j ACCEPT
    iptables -A FORWARD -i $TUN_INTERFACE -o wg0 -m state --state ESTABLISHED,RELATED -j ACCEPT
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    apt install -y iptables-persistent

    # systemd service
    cat <<EOF > /etc/systemd/system/rtxvpn.service
[Unit]
Description=RTX-VPN Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/rtxvpn_v2/tunnel/tunnel.py
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable rtxvpn.service
    systemctl start rtxvpn.service

    generate_uuid

    if [[ "$ENABLE_EDGE" == "y" ]]; then
        echo "${GOLD}Edge will be enabled. Make sure edge.py is configured for remote server.${NC}"
    fi

    echo "${GREEN}Tunnel setup complete!${NC}"
}

root_check
clear
echo "${GREEN}RTX-VPN Tunnel Installer with Edge and Auto UUID${NC}"
echo ""
echo "Choose an option:"
echo "1. Install Tunnel"
echo "2. Uninstall Tunnel"
echo ""

while true; do
    read -p "Enter choice (1 or 2): " choice
    case $choice in
        1)
            install_check
            download_tunnel_files
            tunnel_setup
            break
            ;;
        2)
            uninstall
            break
            ;;
        *)
            echo "Invalid choice. Enter 1 or 2."
            ;;
    esac
done
