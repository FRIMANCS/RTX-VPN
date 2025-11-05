#!/bin/bash
# RTX-VPN Light Installer (Tunnel + Edge)
# MmD

GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
GOLD=$(tput setaf 3)
NC=$(tput sgr0)

UUID=""

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
  echo "Uninstalling RTX-VPN v2..."
  rm -rf /opt/rtxvpn_v2/tunnel /opt/rtxvpn_v2/edge
  systemctl stop rtxvpn.service 2>/dev/null
  systemctl disable rtxvpn.service 2>/dev/null
  rm -f /etc/systemd/system/rtxvpn.service
  echo "${GREEN}RTX-VPN removed!${NC}"
}

download_tunnel_files() {
  apt update && apt install -y wget unzip python3 iproute2 iptables uuid-runtime

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
      ;;
    aarch64)
      wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
      wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-arm64.zip
      wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
      unzip /opt/rtxvpn_v2/tunnel/rathole-aarch64-unknown-linux-musl.zip -d /opt/rtxvpn_v2/tunnel/
      unzip /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64.zip -d /opt/rtxvpn_v2/tunnel/
      unzip /opt/rtxvpn_v2/tunnel/Xray-linux-arm64-v8a.zip -d /opt/rtxvpn_v2/tunnel/
      mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64 /opt/rtxvpn_v2/tunnel/tun2socks
      ;;
    *)
      echo "${RED}Unsupported CPU architecture: $CPU_ARCH${NC}"
      exit 1
      ;;
  esac

  # Configs
  wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.json
  wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.toml
  wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.py
  chmod -R +x /opt/rtxvpn_v2/tunnel/
}

download_edge_files() {
  apt update && apt install -y wget unzip python3

  mkdir -p /opt/rtxvpn_v2/edge

  CPU_ARCH=$(uname -m)
  case $CPU_ARCH in
    x86_64)
      wget -P /opt/rtxvpn_v2/edge https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
      wget -P /opt/rtxvpn_v2/edge https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
      unzip /opt/rtxvpn_v2/edge/rathole-x86_64-unknown-linux-gnu.zip -d /opt/rtxvpn_v2/edge
      unzip /opt/rtxvpn_v2/edge/Xray-linux-64.zip -d /opt/rtxvpn_v2/edge
      ;;
    aarch64)
      wget -P /opt/rtxvpn_v2/edge https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
      wget -P /opt/rtxvpn_v2/edge https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
      unzip /opt/rtxvpn_v2/edge/rathole-aarch64-unknown-linux-musl.zip -d /opt/rtxvpn_v2/edge
      unzip /opt/rtxvpn_v2/edge/Xray-linux-arm64-v8a.zip -d /opt/rtxvpn_v2/edge
      ;;
  esac

  wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.json
  wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.toml
  wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.py
  chmod -R +x /opt/rtxvpn_v2/edge/
}

uuid_tunnel() {
  UUID=$(uuidgen)
  sed -i "s/\"uuid\"/\"$UUID\"/g" /opt/rtxvpn_v2/tunnel/tunnel.json
  sed -i "s/\"uuid\"/\"$UUID\"/g" /opt/rtxvpn_v2/tunnel/tunnel.toml
}

uuid_edge() {
  read -p "Enter UUID: " UUID
  read -p "Enter Tunnel IP: " TUNNEL_IP
  sed -i "s/\"uuid\"/\"$UUID\"/g" /opt/rtxvpn_v2/edge/edge.json
  sed -i "s/\"uuid\"/\"$UUID\"/g" /opt/rtxvpn_v2/edge/edge.toml
  sed -i "s/remote_addr = \".*:[0-9]\+\"/remote_addr = \"$TUNNEL_IP:7081\"/" /opt/rtxvpn_v2/edge/edge.toml
}

tunnel_setup() {
  read -p "Enter TUN interface name (default: rtx): " TUN_INTERFACE
  TUN_INTERFACE=${TUN_INTERFACE:-rtx}
  read -p "Enter client IP range (CIDR, e.g., 192.192.192.0/24): " CLIENT_RANGE

  ip link show $TUN_INTERFACE >/dev/null 2>&1 || ip tuntap add mode tun dev $TUN_INTERFACE
  ip link set dev $TUN_INTERFACE up

  grep -q "200 rtx_table" /etc/iproute2/rt_tables || echo "200 rtx_table" >> /etc/iproute2/rt_tables
  ip route add default dev $TUN_INTERFACE table rtx_table
  ip route add $CLIENT_RANGE dev $TUN_INTERFACE table rtx_table
  ip rule add from $CLIENT_RANGE table rtx_table priority 100

  echo 1 > /proc/sys/net/ipv4/ip_forward
  iptables -A FORWARD -i $TUN_INTERFACE -o $TUN_INTERFACE -m state --state ESTABLISHED,RELATED -j ACCEPT
  iptables -A FORWARD -i $TUN_INTERFACE -o $TUN_INTERFACE -j ACCEPT
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  sysctl -p
  apt install -y iptables-persistent

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
}

edge_setup() {
  cat <<EOF > /etc/systemd/system/rtxvpn.service
[Unit]
Description=RTX-VPN Edge Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/rtxvpn_v2/edge/edge.py
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable rtxvpn.service
  systemctl start rtxvpn.service
}

# -------- Main Menu --------
root_check
clear
echo ""
echo "${GREEN}RTX-VPN Tunnel Installer (Light Version)${NC}"
echo ""
echo "Choose an option:"
echo "1. Setup Tunnel"
echo "2. Setup Edge"
echo "3. Uninstall"
echo ""

while true; do
  read -p "Enter your choice (1, 2, or 3): " choice
  case $choice in
    1)
      install_check
      download_tunnel_files
      uuid_tunnel
      tunnel_setup
      echo "${GREEN}Tunnel installed! UUID: $UUID${NC}"
      break
      ;;
    2)
      install_check
      download_edge_files
      uuid_edge
      edge_setup
      echo "${GREEN}Edge installed!${NC}"
      break
      ;;
    3)
      uninstall
      break
      ;;
    *)
      echo "Invalid option. Please enter 1, 2, or 3."
      ;;
  esac
done
