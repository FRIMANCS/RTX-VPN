#!/bin/bash
# RTX-VPN v2 Forked - SoftEther Removed
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
GOLD=$(tput setaf 3)
CYAN=$(tput setaf 6)
NC=$(tput sgr0)

UUID=""
TUNNEL_IP=""
USER_PORTS=""

root_check() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as ${RED}root!${NC}"
    exit 1
  fi
}

install_check() {
    if [ -d "/opt/rtxvpn_v2/tunnel" ] || [ -d "/opt/rtxvpn_v2/edge" ]; then
        echo "RTX-VPN v2 is already ${GREEN}installed!${NC}"
        exit 1
    fi
}

uninstall() {
    echo "Removing RTX-VPN v2..."
    rm -rf /opt/rtxvpn_v2
    systemctl stop rtxvpn.service 2>/dev/null
    systemctl disable rtxvpn.service 2>/dev/null
    rm -f /etc/systemd/system/rtxvpn.service
    echo "${GREEN}Removed.${NC}"
}

download_edge_files(){
    apt update && apt install tar sudo wget unzip python3 -y
    mkdir -p /opt/rtxvpn_v2/edge

    CPU_ARCH=$(uname -m)
    case $CPU_ARCH in
        "x86_64")
            wget -P /opt/rtxvpn_v2/edge https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
            wget -P /opt/rtxvpn_v2/edge https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
            unzip /opt/rtxvpn_v2/edge/rathole-x86_64-unknown-linux-gnu.zip -d /opt/rtxvpn_v2/edge
            unzip /opt/rtxvpn_v2/edge/Xray-linux-64.zip -d /opt/rtxvpn_v2/edge
            wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/edge.json
            wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/edge.toml
            wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/edge.py
            chmod -R +x /opt/rtxvpn_v2/edge/
            ;;
        "aarch64")
            wget -P /opt/rtxvpn_v2/edge/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
            wget -P /opt/rtxvpn_v2/edge/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
            unzip /opt/rtxvpn_v2/edge/rathole-aarch64-unknown-linux-musl.zip -d /opt/rtxvpn_v2/edge/
            unzip /opt/rtxvpn_v2/edge/Xray-linux-arm64-v8a.zip -d /opt/rtxvpn_v2/edge/
            wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/edge.json
            wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/edge.toml
            wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/edge.py
            chmod -R +x /opt/rtxvpn_v2/edge/
            ;;
        *)
            echo "${RED}Unsupported CPU architecture: $CPU_ARCH${NC}"
            exit 1
            ;;
    esac
}

download_tunnel_files() {
    apt update && apt install tar sudo wget unzip dnsmasq iptables build-essential python3 -y
    mkdir -p /opt/rtxvpn_v2/tunnel

    CPU_ARCH=$(uname -m)
    case $CPU_ARCH in
        "x86_64")
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-amd64.zip
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
            unzip /opt/rtxvpn_v2/tunnel/rathole-x86_64-unknown-linux-gnu.zip -d /opt/rtxvpn_v2/tunnel/
            unzip /opt/rtxvpn_v2/tunnel/tun2socks-linux-amd64.zip -d /opt/rtxvpn_v2/tunnel/
            unzip /opt/rtxvpn_v2/tunnel/Xray-linux-64.zip -d /opt/rtxvpn_v2/tunnel/
            wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/tunnel.json
            wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/tunnel.toml
            wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/tunnel.py
            mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-amd64 /opt/rtxvpn_v2/tunnel/tun2socks
            chmod -R +x /opt/rtxvpn_v2/tunnel/
            ;;
        "aarch64")
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-arm64.zip
            wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
            unzip /opt/rtxvpn_v2/tunnel/rathole-aarch64-unknown-linux-musl.zip -d /opt/rtxvpn_v2/tunnel/
            unzip /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64.zip -d /opt/rtxvpn_v2/tunnel/
            unzip /opt/rtxvpn_v2/tunnel/Xray-linux-arm64-v8a.zip -d /opt/rtxvpn_v2/tunnel/
            wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/tunnel.json
            wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/tunnel.toml
            wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/v2/configs/tunnel.py
            mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64 /opt/rtxvpn_v2/tunnel/tun2socks
            chmod -R +x /opt/rtxvpn_v2/tunnel/
            ;;
        *)
            echo "${RED}Unsupported CPU architecture: $CPU_ARCH${NC}"
            exit 1
            ;;
    esac
}

tunnel_setup(){
    echo "100 rtx_table" >> /etc/iproute2/rt_tables
    read -p "Enter Tunnel IP: " TUNNEL_IP
    read -p "Enter ports to open (comma-separated, e.g., 2088,443): " USER_PORTS

    cat <<EOF > /etc/systemd/system/rtxvpn.service
[Unit]
Description=RTX-VPN Tunnel Service
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/rtxvpn_v2/tunnel/tunnel.py
ExecStop=/bin/kill -SIGINT \$MAINPID
Restart=on-failure
User=root
Group=root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
PIDFile=/var/run/vpn-service.pid
[Install]
WantedBy=multi-user.target
EOF

    systemctl enable rtxvpn.service
    systemctl start rtxvpn.service

    ip link set dev rtx down 2>/dev/null
    ip tuntap del mode tun dev rtx 2>/dev/null
    ip tuntap add mode tun dev rtx
    ip link set dev rtx up
    ip route add default dev rtx table rtx_table
    ip route add $TUNNEL_IP/32 dev rtx table rtx_table
    ip rule add from $TUNNEL_IP/32 table rtx_table priority 100
    iptables -A FORWARD -i rtx -j ACCEPT
    iptables -A FORWARD -o rtx -j ACCEPT

    for port in $(echo $USER_PORTS | tr ',' ' '); do
        iptables -A INPUT -p tcp --dport $port -j ACCEPT
        iptables -A INPUT -p udp --dport $port -j ACCEPT
    done

    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    apt install iptables-persistent -y
}

edge_setup(){
    read -p "Enter Edge UUID: " UUID
    sed -i "s/\"uuid\"/\"$UUID\"/g" /opt/rtxvpn_v2/edge/edge.json
    sed -i "s/\"uuid\"/\"$UUID\"/g" /opt/rtxvpn_v2/edge/edge.toml

    cat <<EOF > /etc/systemd/system/rtxvpn.service
[Unit]
Description=RTX-VPN Edge Service
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/rtxvpn_v2/edge/edge.py
ExecStop=/bin/kill -SIGINT \$MAINPID
Restart=on-failure
User=root
Group=root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
PIDFile=/var/run/vpn-service.pid
[Install]
WantedBy=multi-user.target
EOF

    systemctl enable rtxvpn.service
    systemctl start rtxvpn.service
}

root_check
clear
echo "${GREEN}RTX-VPN v2 Fork (SoftEther Removed)${NC}"
echo ""
echo "Choose an option:"
echo "1.Setup Tunnel"
echo "2.Setup Edge"
echo "3.Uninstall"
while true; do
    read -p "Enter your choice (1, 2 or 3): " choice
    case $choice in
        1)
            install_check
            download_tunnel_files
            tunnel_setup
            echo "${GREEN}Tunnel installed!${NC}"
            break
            ;;
        2)
            install_check
            download_edge_files
            edge_setup
            echo "${GREEN}Edge installed!${NC}"
            break
            ;;
        3)
            uninstall
            break
            ;;
        *)
            echo "Invalid option. Enter 1, 2, or 3."
            ;;
    esac
done
