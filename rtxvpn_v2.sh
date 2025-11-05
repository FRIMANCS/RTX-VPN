#!/bin/bash
# RTX-VPN Installer (SoftEther removed) + WG->RTX routing helper
# MmD (edited)

set -euo pipefail
IFS=$'\n\t'

GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
NC=$(tput sgr0)

UUID=""

root_check() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}This script must be run as root!${NC}"
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
  echo ""
  read -p "This will remove all RTX-VPN v2 files (Tunnel & Edge). Continue? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Canceled."
    return
  fi

  systemctl stop rtxvpn.service 2>/dev/null || true
  systemctl disable rtxvpn.service 2>/dev/null || true

  rm -f /etc/systemd/system/rtxvpn.service || true
  rm -rf /opt/rtxvpn_v2/tunnel /opt/rtxvpn_v2/edge || true

  # Remove rtx_table entry if exists (200 was used originally; we used 100 in some variants — try both)
  sed -i '/\b100 rtx_table\b/d' /etc/iproute2/rt_tables 2>/dev/null || true
  sed -i '/\b200 rtx_table\b/d' /etc/iproute2/rt_tables 2>/dev/null || true

  # remove possible rtx link and rules
  ip link set dev rtx down 2>/dev/null || true
  ip tuntap del mode tun dev rtx 2>/dev/null || true
  ip rule del from 192.192.192.0/24 table rtx_table 2>/dev/null || true
  ip route flush table rtx_table 2>/dev/null || true

  # wipe related iptables we may have added
  iptables -t nat -D POSTROUTING -s 192.192.192.0/24 -o rtx -j MASQUERADE 2>/dev/null || true
  iptables -D FORWARD -i wg0 -o rtx -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -i rtx -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

  netfilter-persistent save 2>/dev/null || true

  echo "${GREEN}Uninstalled.${NC}"
}

download_tunnel_files() {
  apt update
  apt install -y tar sudo wget unzip iproute2 iptables build-essential python3

  mkdir -p /opt/rtxvpn_v2/tunnel

  CPU_ARCH=$(uname -m)
  case $CPU_ARCH in
    x86_64)
      wget -q -P /opt/rtxvpn_v2/tunnel/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
      wget -q -P /opt/rtxvpn_v2/tunnel/ https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-amd64.zip
      wget -q -P /opt/rtxvpn_v2/tunnel/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
      unzip -q /opt/rtxvpn_v2/tunnel/rathole-*.zip -d /opt/rtxvpn_v2/tunnel/
      unzip -q /opt/rtxvpn_v2/tunnel/tun2socks-*.zip -d /opt/rtxvpn_v2/tunnel/
      unzip -q /opt/rtxvpn_v2/tunnel/Xray-linux-64.zip -d /opt/rtxvpn_v2/tunnel/
      mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-amd64 /opt/rtxvpn_v2/tunnel/tun2socks 2>/dev/null || true
      ;;
    aarch64)
      wget -q -P /opt/rtxvpn_v2/tunnel/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
      wget -q -P /opt/rtxvpn_v2/tunnel/ https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-arm64.zip
      wget -q -P /opt/rtxvpn_v2/tunnel/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
      unzip -q /opt/rtxvpn_v2/tunnel/rathole-*.zip -d /opt/rtxvpn_v2/tunnel/
      unzip -q /opt/rtxvpn_v2/tunnel/tun2socks-*.zip -d /opt/rtxvpn_v2/tunnel/
      unzip -q /opt/rtxvpn_v2/tunnel/Xray-*.zip -d /opt/rtxvpn_v2/tunnel/
      mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64 /opt/rtxvpn_v2/tunnel/tun2socks 2>/dev/null || true
      ;;
    *)
      echo "${RED}Unsupported CPU architecture: $CPU_ARCH${NC}"
      exit 1
      ;;
  esac

  # configs (from original repo)
  wget -q -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.json
  wget -q -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.toml
  wget -q -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.py

  chmod -R +x /opt/rtxvpn_v2/tunnel/
}

# Edge downloader left intact
download_edge_files() {
  apt update
  apt install -y tar sudo wget unzip python3
  mkdir -p /opt/rtxvpn_v2/edge
  CPU_ARCH=$(uname -m)
  case $CPU_ARCH in
    x86_64)
      wget -q -P /opt/rtxvpn_v2/edge https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
      wget -q -P /opt/rtxvpn_v2/edge https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
      unzip -q /opt/rtxvpn_v2/edge/*.zip -d /opt/rtxvpn_v2/edge
      ;;
    aarch64)
      wget -q -P /opt/rtxvpn_v2/edge https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
      wget -q -P /opt/rtxvpn_v2/edge https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
      unzip -q /opt/rtxvpn_v2/edge/*.zip -d /opt/rtxvpn_v2/edge
      ;;
  esac
  wget -q -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.json
  wget -q -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.toml
  wget -q -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.py
  chmod -R +x /opt/rtxvpn_v2/edge/
}

# Tunnel service (no SoftEther dependency)
tunnel_setup() {
  # add rtx_table entry once
  grep -q "100 rtx_table" /etc/iproute2/rt_tables || echo "100 rtx_table" >> /etc/iproute2/rt_tables

  # Create systemd service to run tunnel.py
  cat > /etc/systemd/system/rtxvpn.service <<'EOF'
[Unit]
Description=RTX-VPN Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/rtxvpn_v2/tunnel/tunnel.py
Restart=on-failure
User=root
Group=root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable rtxvpn.service
  systemctl start rtxvpn.service

  # ensure ip forward and persistent
  sysctl -w net.ipv4.ip_forward=1
  grep -qxF 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

  apt install -y iptables-persistent
}

edge_setup() {
  cat > /etc/systemd/system/rtxvpn.service <<'EOF'
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

uuid_tunnel() {
  # try to use xray uuid binary if present, fallback to uuidgen
  if [ -x /opt/rtxvpn_v2/tunnel/xray ]; then
    UUID=$(/opt/rtxvpn_v2/tunnel/xray uuid)
  else
    UUID=$(uuidgen)
  fi
  sed -i "s/\"uuid\"/\"$UUID\"/g" /opt/rtxvpn_v2/tunnel/tunnel.json || true
  sed -i "s/\"uuid\"/\"$UUID\"/g" /opt/rtxvpn_v2/tunnel/tunnel.toml || true
  echo "Generated UUID: $UUID"
}

uuid_edge() {
  read -p "Enter UUID: " UUID
  read -p "Enter Tunnel IP: " TUNNEL_IP
  sed -i "s/\"uuid\"/\"$UUID\"/g" "/opt/rtxvpn_v2/edge/edge.json" || true
  sed -i "s/\"uuid\"/\"$UUID\"/g" "/opt/rtxvpn_v2/edge/edge.toml" || true
  sed -i "s/remote_addr = \".*:[0-9]\+\"/remote_addr = \"$TUNNEL_IP:7081\"/" "/opt/rtxvpn_v2/edge/edge.toml" || true
}

# ===== WG -> RTX routing helper (clean + prompt) =====
wg_to_rtx_setup() {
  echo ""
  echo "${CYAN}WG -> RTX routing setup (will clean old state and re-create)${NC}"
  read -p "Enter WireGuard interface name (default: wg0): " WG_IF
  WG_IF=${WG_IF:-wg0}
  read -p "Enter client CIDR (default: 192.192.192.0/24): " WG_RANGE
  WG_RANGE=${WG_RANGE:-192.192.192.0/24}
  read -p "Enter RTX tunnel IP (default: 198.19.0.1): " RTX_IP
  RTX_IP=${RTX_IP:-198.19.0.1}
  RTX_PORT=2088
  echo "Using: interface=$WG_IF, client_cidr=$WG_RANGE, rtx_ip=$RTX_IP, rtx_port=$RTX_PORT"

  # 1. enable forwarding
  sysctl -w net.ipv4.ip_forward=1
  grep -qxF 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

  # 2. remove old rtx link if exists
  ip link set dev rtx down 2>/dev/null || true
  ip tuntap del mode tun dev rtx 2>/dev/null || true

  # 3. remove old ip rules/routes for this WG_RANGE
  # attempt to remove any ip rule that references the table rtx_table and this cidr
  for rule in $(ip rule show | awk '{print $0}'); do
    true
  done
  # remove specific rule (ignore errors)
  ip rule del from "$WG_RANGE" table rtx_table 2>/dev/null || true

  # 4. flush rtx_table
  ip route flush table rtx_table 2>/dev/null || true

  # 5. remove old iptables entries we might have added (safe remove)
  iptables -t nat -D POSTROUTING -s "$WG_RANGE" -o rtx -j MASQUERADE 2>/dev/null || true
  iptables -D FORWARD -i "$WG_IF" -o rtx -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -i rtx -o "$WG_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

  # 6. create rtx_table entry if missing
  grep -q "100 rtx_table" /etc/iproute2/rt_tables || echo "100 rtx_table" >> /etc/iproute2/rt_tables

  # 7. create rtx link and bring up
  ip tuntap add mode tun dev rtx 2>/dev/null || true
  ip link set dev rtx up

  # 8. add routes to table (only if not exist)
  ip route show table rtx_table | grep -q "^default .*dev rtx" || ip route add default dev rtx table rtx_table
  ip route show table rtx_table | grep -q "^$WG_RANGE .*dev $WG_IF" || ip route add "$WG_RANGE" dev "$WG_IF" table rtx_table

  # 9. add ip rule if missing
  if ! ip rule show | grep -q "from $WG_RANGE lookup rtx_table"; then
    ip rule add from "$WG_RANGE" table rtx_table priority 100
  fi

  # 10. iptables: add forwarding + nat
  iptables -A FORWARD -i "$WG_IF" -o rtx -j ACCEPT
  iptables -A FORWARD -i rtx -o "$WG_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -t nat -A POSTROUTING -s "$WG_RANGE" -o rtx -j MASQUERADE

  # 11. persist iptables
  apt install -y iptables-persistent
  netfilter-persistent save || true

  echo "${GREEN}✅ WG->RTX routing configured.${NC}"
}

# ===== Menu =====
root_check
clear
cat <<'EOF'
  _____ _________   __  __      _______  _   _
 |  __ \__   __\ \ / /  \ \    / /  __ \| \ | |
 | |__) | | |   \ V /    ____\ \  / /| |__) |  \| |
 |  _  /  | |    > <    ______\ \/ / |  ___/| .   |
 | | \ \  | |   / . \        \  /  | |    | |\  |
 |_|  \_\ |_|  /_/ \_\  V2  \/   |_|    |_| \_|
EOF

echo ""
echo "Choose an option:"
echo "1. Setup Tunnel"
echo "2. Setup Edge"
echo "3. Setup WG->RTX Routing"
echo "4. Uninstall"
echo ""

while true; do
  read -p "Enter your choice (1-4): " choice
  case "$choice" in
    1)
      install_check
      download_tunnel_files
      uuid_tunnel
      tunnel_setup
      echo ""
      echo "${GREEN}Tunnel installed! UUID: $UUID${NC}"
      break
      ;;
    2)
      install_check
      download_edge_files
      uuid_edge
      edge_setup
      echo ""
      echo "${GREEN}Edge installed!${NC}"
      break
      ;;
    3)
      wg_to_rtx_setup
      break
      ;;
    4)
      uninstall
      break
      ;;
    *)
      echo "Invalid option. Enter 1-4."
      ;;
  esac
done
