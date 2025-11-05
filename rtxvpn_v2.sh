#!/bin/bash
# MmD - RTX-VPN v2 (No SoftEther) - Unified Tunnel/Edge installer
# توضیحات: این نسخه SoftEther را حذف می‌کند. از rathole + xray + tun2socks استفاده می‌کند.
set -e

GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
GOLD=$(tput setaf 3)
CYAN=$(tput setaf 6)
NC=$(tput sgr0)

BASE_DIR="/opt/rtxvpn_v2"
TUNNEL_DIR="$BASE_DIR/tunnel"
EDGE_DIR="$BASE_DIR/edge"
SERVICE="/etc/systemd/system/rtxvpn.service"

root_check() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as ${RED}root!${NC}"
    exit 1
  fi
}

install_check() {
    if [ -d "$TUNNEL_DIR" ] || [ -d "$EDGE_DIR" ]; then
        echo "RTX-VPN v2 is already ${GREEN}installed!${NC}"
        # don't exit automatically; allow reinstall if user chooses uninstall first
    fi
}

# ---------- Uninstall / Cleanup ----------
uninstall() {
    echo "${RED}Stopping and removing RTX-VPN...${NC}"

    # stop service
    if systemctl is-active --quiet rtxvpn.service; then
        systemctl stop rtxvpn.service || true
    fi
    systemctl disable rtxvpn.service 2>/dev/null || true
    rm -f "$SERVICE" 2>/dev/null || true

    # remove files
    rm -rf "$BASE_DIR"

    # remove ip rules/routes/interfaces created by script
    ip link set dev rtx down 2>/dev/null || true
    ip tuntap del mode tun dev rtx 2>/dev/null || true

    # try remove table entry
    sed -i '/100 rtx_table/d' /etc/iproute2/rt_tables 2>/dev/null || true

    # flush rtx table
    ip route flush table rtx_table 2>/dev/null || true

    # remove ip rules referencing rtx_table (best-effort)
    # We attempt to remove rules that match typical priorities (100)
    ip rule del priority 100 table rtx_table 2>/dev/null || true

    # remove common iptables rules we add (best-effort)
    # Remove forward rules between rtx and any wg/tun interface seen
    for IF in $(ip -o link show | awk -F': ' '{print $2}'); do
        iptables -D FORWARD -i "$IF" -o rtx -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -i rtx -o "$IF" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    done

    # remove nat masquerade we added for common subnets (best-effort)
    iptables -t nat -F POSTROUTING 2>/dev/null || true

    # save persistent rules if package exists
    if command -v netfilter-persistent >/dev/null 2>&1 || dpkg -l iptables-persistent >/dev/null 2>&1; then
        netfilter-persistent save 2>/dev/null || true
    fi

    echo "${GREEN}Uninstall/cleanup finished.${NC}"
}

# ---------- Download helpers ----------
download_edge_files(){
    apt update
    apt install -y tar sudo wget unzip python3

    if [ ! -d "$EDGE_DIR" ]; then
        mkdir -p "$EDGE_DIR"
    fi

    CPU_ARCH=$(uname -m)
    case $CPU_ARCH in
        x86_64)
            wget -q -P "$EDGE_DIR" https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
            wget -q -P "$EDGE_DIR" https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
            unzip -o "$EDGE_DIR"/rathole-x86_64-unknown-linux-gnu.zip -d "$EDGE_DIR"
            unzip -o "$EDGE_DIR"/Xray-linux-64.zip -d "$EDGE_DIR"
            wget -q -P "$EDGE_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.json
            wget -q -P "$EDGE_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.toml
            wget -q -P "$EDGE_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.py
            chmod -R +x "$EDGE_DIR"
            ;;
        aarch64|arm64)
            wget -q -P "$EDGE_DIR" https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
            wget -q -P "$EDGE_DIR" https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
            unzip -o "$EDGE_DIR"/rathole-aarch64-unknown-linux-musl.zip -d "$EDGE_DIR"
            unzip -o "$EDGE_DIR"/Xray-linux-arm64-v8a.zip -d "$EDGE_DIR"
            wget -q -P "$EDGE_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.json
            wget -q -P "$EDGE_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.toml
            wget -q -P "$EDGE_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.py
            chmod -R +x "$EDGE_DIR"
            ;;
        *)
            echo "${RED}Unsupported CPU architecture: $CPU_ARCH${NC}"
            exit 1
            ;;
    esac
}

download_tunnel_files() {
    apt update
    apt install -y tar sudo wget unzip dnsmasq iptables build-essential python3

    if [ ! -d "$TUNNEL_DIR" ]; then
        mkdir -p "$TUNNEL_DIR"
    fi

    CPU_ARCH=$(uname -m)
    case $CPU_ARCH in
        x86_64)
            wget -q -P "$TUNNEL_DIR" https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
            wget -q -P "$TUNNEL_DIR" https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-amd64.zip
            wget -q -P "$TUNNEL_DIR" https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
            unzip -o "$TUNNEL_DIR"/rathole-x86_64-unknown-linux-gnu.zip -d "$TUNNEL_DIR"
            unzip -o "$TUNNEL_DIR"/tun2socks-linux-amd64.zip -d "$TUNNEL_DIR"
            unzip -o "$TUNNEL_DIR"/Xray-linux-64.zip -d "$TUNNEL_DIR"
            mv "$TUNNEL_DIR"/tun2socks-linux-amd64 "$TUNNEL_DIR"/tun2socks 2>/dev/null || true
            chmod -R +x "$TUNNEL_DIR"
            wget -q -P "$TUNNEL_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.json
            wget -q -P "$TUNNEL_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.toml
            wget -q -P "$TUNNEL_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.py
            ;;
        aarch64|arm64)
            wget -q -P "$TUNNEL_DIR" https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
            wget -q -P "$TUNNEL_DIR" https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-arm64.zip
            wget -q -P "$TUNNEL_DIR" https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
            unzip -o "$TUNNEL_DIR"/rathole-aarch64-unknown-linux-musl.zip -d "$TUNNEL_DIR"
            unzip -o "$TUNNEL_DIR"/tun2socks-linux-arm64.zip -d "$TUNNEL_DIR"
            unzip -o "$TUNNEL_DIR"/Xray-linux-arm64-v8a.zip -d "$TUNNEL_DIR"
            mv "$TUNNEL_DIR"/tun2socks-linux-arm64 "$TUNNEL_DIR"/tun2socks 2>/dev/null || true
            chmod -R +x "$TUNNEL_DIR"
            wget -q -P "$TUNNEL_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.json
            wget -q -P "$TUNNEL_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.toml
            wget -q -P "$TUNNEL_DIR" https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.py
            ;;
        *)
            echo "${RED}Unsupported CPU architecture: $CPU_ARCH${NC}"
            exit 1
            ;;
    esac
}

# ---------- UUID helpers ----------
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

uuid_tunnel() {
  UUID=$(generate_uuid)
  # Replace placeholder "uuid" in tunnel configs if present
  if [ -f "$TUNNEL_DIR/tunnel.json" ]; then
      sed -i "s/\"uuid\"/\"$UUID\"/g" "$TUNNEL_DIR/tunnel.json" || true
  fi
  if [ -f "$TUNNEL_DIR/tunnel.toml" ]; then
      sed -i "s/\"uuid\"/\"$UUID\"/g" "$TUNNEL_DIR/tunnel.toml" || true
  fi
  echo "$UUID"
}

uuid_edge() {
  read -p "Enter UUID for edge (leave empty to auto-generate): " UUID
  if [ -z "$UUID" ]; then
    UUID=$(generate_uuid)
    echo "Generated UUID: $UUID"
  fi
  read -p "Enter Tunnel remote address (IP or domain) (example 1.2.3.4) : " TUNNEL_IP
  # replace in edge configs
  if [ -f "$EDGE_DIR/edge.json" ]; then
      sed -i "s/\"uuid\"/\"$UUID\"/g" "$EDGE_DIR/edge.json" || true
  fi
  if [ -f "$EDGE_DIR/edge.toml" ]; then
      sed -i "s/\"uuid\"/\"$UUID\"/g" "$EDGE_DIR/edge.toml" || true
      if [ -n "$TUNNEL_IP" ]; then
         sed -i "s/remote_addr = \".*:[0-9]\+\"/remote_addr = \"$TUNNEL_IP:7081\"/" "$EDGE_DIR/edge.toml" || true
      fi
  fi
  echo "$UUID"
}

# ---------- dnsmasq setup (optional in tunnel) ----------
dnsmasq_setup(){
    apt install -y dnsmasq
    if [ -f /etc/dnsmasq.conf ]; then
        mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup 2>/dev/null || true
    fi
    cat <<EOF > /etc/dnsmasq.conf
interface=tap_softether
dhcp-range=tap_softether,198.19.0.2,198.19.0.254,12h
dhcp-option=tap_softether,3,198.19.0.1
dhcp-option=tap_softether,6,8.8.8.8,8.8.4.4
EOF
    systemctl enable dnsmasq
    systemctl restart dnsmasq
}

# ---------- tunnel setup (no SoftEther) ----------
tunnel_setup(){
  WG_IFACE="$1"
  WG_SUBNET="$2"
  OPEN_PORTS="$3"

  # add route table if missing
  grep -q "^100 rtx_table" /etc/iproute2/rt_tables || echo "100 rtx_table" >> /etc/iproute2/rt_tables

  # remove old rtx if exists
  ip link set dev rtx down 2>/dev/null || true
  ip tuntap del mode tun dev rtx 2>/dev/null || true

  # create rtx tun device
  ip tuntap add mode tun dev rtx || true
  ip link set dev rtx up

  # add routes in rtx table
  ip route add default dev rtx table rtx_table || true
  ip route add "$WG_SUBNET" dev "$WG_IFACE" table rtx_table || true

  # add ip rule
  ip rule add from "$WG_SUBNET" table rtx_table priority 100 2>/dev/null || true

  # enable forwarding
  sysctl -w net.ipv4.ip_forward=1
  if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
      echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
  fi

  # forwarding iptables between wg iface and rtx
  iptables -A FORWARD -i "$WG_IFACE" -o rtx -j ACCEPT || true
  iptables -A FORWARD -i rtx -o "$WG_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT || true

  # NAT for subnet out via rtx
  iptables -t nat -A POSTROUTING -s "$WG_SUBNET" -o rtx -j MASQUERADE || true

  # Open requested ports (both tcp and udp) on local machine (INPUT chain)
  for p in $OPEN_PORTS; do
      if ! iptables -C INPUT -p tcp --dport "$p" -j ACCEPT >/dev/null 2>&1; then
          iptables -A INPUT -p tcp --dport "$p" -j ACCEPT || true
      fi
      if ! iptables -C INPUT -p udp --dport "$p" -j ACCEPT >/dev/null 2>&1; then
          iptables -A INPUT -p udp --dport "$p" -j ACCEPT || true
      fi
  done

  # persist iptables (install package if needed)
  apt install -y iptables-persistent || true
  netfilter-persistent save || true

  # UUIDs and configs
  GENERATED_UUID=$(uuid_tunnel)
  echo ""
  echo "${GREEN}Tunnel UUID:${NC} ${GOLD}$GENERATED_UUID${NC}"
  echo ""

  # create systemd service
  cat <<EOF > "$SERVICE"
[Unit]
Description=RTX-VPN Tunnel Service (rathole + xray + tun2socks)
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $TUNNEL_DIR/tunnel.py
ExecStop=/bin/kill -SIGINT \$MAINPID
Restart=on-failure
User=root
Group=root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable rtxvpn.service
  systemctl start rtxvpn.service || true

  echo ""
  echo "${GREEN}Tunnel setup complete.${NC} forwarding from ${CYAN}$WG_IFACE${NC} (${GOLD}$WG_SUBNET${NC}) through rtx interface."
  echo "Opened ports: ${GOLD}$OPEN_PORTS${NC}"
  echo ""
  echo "Check service status: ${CYAN}systemctl status rtxvpn${NC}"
}

# ---------- edge setup ----------
edge_setup(){
  WG_IFACE="$1"
  WG_SUBNET="$2"
  OPEN_PORTS="$3"

  # open requested ports (both tcp and udp) on local machine (INPUT chain)
  for p in $OPEN_PORTS; do
      if ! iptables -C INPUT -p tcp --dport "$p" -j ACCEPT >/dev/null 2>&1; then
          iptables -A INPUT -p tcp --dport "$p" -j ACCEPT || true
      fi
      if ! iptables -C INPUT -p udp --dport "$p" -j ACCEPT >/dev/null 2>&1; then
          iptables -A INPUT -p udp --dport "$p" -j ACCEPT || true
      fi
  done

  apt install -y iptables-persistent || true
  netfilter-persistent save || true

  # UUID and config adjustments
  EDGE_UUID=$(uuid_edge)
  echo ""
  echo "${GREEN}Edge UUID:${NC} ${GOLD}$EDGE_UUID${NC}"
  echo ""

  # create systemd service for edge (runs edge.py)
  cat <<EOF > "$SERVICE"
[Unit]
Description=RTX-VPN Edge Service (rathole + xray client)
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $EDGE_DIR/edge.py
ExecStop=/bin/kill -SIGINT \$MAINPID
Restart=on-failure
User=root
Group=root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable rtxvpn.service
  systemctl start rtxvpn.service || true

  echo ""
  echo "${GREEN}Edge setup complete.${NC}"
  echo "Opened ports: ${GOLD}$OPEN_PORTS${NC}"
  echo ""
  echo "Check service status: ${CYAN}systemctl status rtxvpn${NC}"
}

# ---------- interactive menu ----------
main_menu() {
    clear
    echo ""
    echo "${GREEN}  _____ _________   __  __      _______  _   _    ${NC}"
    echo "${GOLD}  RTX-VPN v2 (No SoftEther)${NC}"
    echo ""
    echo "Choose an option:"
    echo "1) Setup Tunnel"
    echo "2) Setup Edge"
    echo "3) Uninstall / Cleanup"
    echo "4) Exit"
    echo ""
    read -p "Enter choice (1-4): " choice
    case "$choice" in
        1)
            echo ""
            read -p "Enter interface name to route from (default: wg0): " WG_IFACE
            WG_IFACE=${WG_IFACE:-wg0}
            read -p "Enter subnet for clients (CIDR) (default: 192.192.192.0/24): " WG_SUBNET
            WG_SUBNET=${WG_SUBNET:-192.192.192.0/24}
            read -p "Enter ports to open (space separated) e.g. \"2088 443 22\": " OPEN_PORTS
            OPEN_PORTS=${OPEN_PORTS:-"2088"}
            install_check
            download_tunnel_files
            # dnsmasq optional setup (kept minimal; only if tap_softether required keep for compatibility)
            dnsmasq_setup || true
            tunnel_setup "$WG_IFACE" "$WG_SUBNET" "$OPEN_PORTS"
            ;;
        2)
            echo ""
            read -p "Enter interface name to route from (default: wg0): " WG_IFACE
            WG_IFACE=${WG_IFACE:-wg0}
            read -p "Enter subnet for clients (CIDR) (default: 192.192.192.0/24): " WG_SUBNET
            WG_SUBNET=${WG_SUBNET:-192.192.192.0/24}
            read -p "Enter ports to open (space separated) e.g. \"2088 443 22\": " OPEN_PORTS
            OPEN_PORTS=${OPEN_PORTS:-"2088"}
            install_check
            download_edge_files
            edge_setup "$WG_IFACE" "$WG_SUBNET" "$OPEN_PORTS"
            ;;
        3)
            echo ""
            read -p "Are you sure you want to uninstall RTX-VPN and remove configs? (y/n): " conf
            if [ "$conf" = "y" ] || [ "$conf" = "Y" ]; then
                uninstall
            else
                echo "Canceled."
            fi
            ;;
        4)
            echo "Bye."
            exit 0
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
}

# run
root_check
main_menu
