#!/bin/bash
#MmD Forked version by FRIMANCS

GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
GOLD=$(tput setaf 3)
CYAN=$(tput setaf 6)
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
    if [ -d "/opt/rtxvpn_v2/tunnel" ]; then
        while true; do
            read -p "This will remove ${CYAN}RTX-VPN v2 (Tunnel)${NC} and its associated files. Are you sure? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "Uninstalling RTX-VPN v2 (Tunnel)..."
                rm -rf "/opt/rtxvpn_v2/tunnel"
                systemctl stop rtxvpn
                systemctl disable rtxvpn
                rm -f /etc/systemd/system/rtxvpn.service
                echo "RTX-VPN service ${GREEN}removed${NC}"
                echo "RTX-VPN v2 (Tunnel) has been ${GREEN}removed${NC}"
                break
            elif [[ "$confirm" =~ ^[Nn]$ ]]; then
                echo "Uninstallation of RTX-VPN v2 (Tunnel) ${RED}canceled${NC}"
                break
            else
                echo "Invalid input. Please enter 'y' or 'n'."
            fi
        done
    fi

    if [ -d "/opt/rtxvpn_v2/edge" ]; then
        while true; do
            read -p "This will remove ${CYAN}RTX-VPN v2 (Edge)${NC} and its associated files. Are you sure? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "Uninstalling RTX-VPN v2 (Edge)..."
                rm -rf "/opt/rtxvpn_v2/edge"
                systemctl stop rtxvpn
                systemctl disable rtxvpn
                rm -f /etc/systemd/system/rtxvpn.service
                echo "RTX-VPN service ${GREEN}removed${NC}"
                echo "RTX-VPN v2 (Edge) has been ${GREEN}removed${NC}"
                break
            elif [[ "$confirm" =~ ^[Nn]$ ]]; then
                echo "Uninstallation of RTX-VPN v2 (Edge) ${RED}canceled${NC}"
                break
            else
                echo "Invalid input. Please enter 'y' or 'n'."
            fi
        done
    else
        echo "RTX-VPN v2 is ${RED}not installed!${NC}"
    fi
}

download_edge_files(){
	apt update && apt install tar sudo wget unzip python3 -y
	if [ ! -d "/opt/rtxvpn_v2/edge" ]; then
		mkdir -p /opt/rtxvpn_v2/edge || { echo -e "${RED}Failed to create /opt/rtxvpn_v2/edge directory!${NC}"; exit 1; }
	fi

	CPU_ARCH=$(uname -m)
	case $CPU_ARCH in
		x86_64)
			wget -P /opt/rtxvpn_v2/edge https://github.com/FRIMANCS/RTX-VPN/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
			wget -P /opt/rtxvpn_v2/edge https://github.com/FRIMANCS/RTX-VPN/releases/download/v25.2.21/Xray-linux-64.zip
			unzip /opt/rtxvpn_v2/edge/rathole-x86_64-unknown-linux-gnu.zip -d /opt/rtxvpn_v2/edge
			unzip /opt/rtxvpn_v2/edge/Xray-linux-64.zip -d /opt/rtxvpn_v2/edge
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/edge.json
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/edge.toml
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/edge.py
			chmod -R +x /opt/rtxvpn_v2/edge/
			;;
		aarch64)
			wget -P /opt/rtxvpn_v2/edge/ https://github.com/FRIMANCS/RTX-VPN/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
			wget -P /opt/rtxvpn_v2/edge/ https://github.com/FRIMANCS/RTX-VPN/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
			unzip /opt/rtxvpn_v2/edge/rathole-aarch64-unknown-linux-musl.zip -d /opt/rtxvpn_v2/edge/
			unzip /opt/rtxvpn_v2/edge/Xray-linux-arm64-v8a.zip -d /opt/rtxvpn_v2/edge/
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/edge.json
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/edge.toml
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/edge.py
			chmod -R +x /opt/rtxvpn_v2/edge/
			;;
		*)
			echo "${RED}Unsupported CPU architecture: $CPU_ARCH${NC}"
			exit 1
			;;
	esac
}

download_tunnel_files() {
	apt update && apt install tar sudo wget unzip dnsmasq iptables python3 -y
	if [ ! -d "/opt/rtxvpn_v2/tunnel/" ]; then
		mkdir -p /opt/rtxvpn_v2/tunnel/ || { echo -e "${RED}Failed to create /opt/rtxvpn_v2/tunnel/ directory!${NC}"; exit 1; }
	fi
	CPU_ARCH=$(uname -m)
	case $CPU_ARCH in
		x86_64)
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/FRIMANCS/RTX-VPN/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/FRIMANCS/RTX-VPN/releases/download/v2.5.2/tun2socks-linux-amd64.zip
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/FRIMANCS/RTX-VPN/releases/download/v25.2.21/Xray-linux-64.zip
			unzip /opt/rtxvpn_v2/tunnel/rathole-x86_64-unknown-linux-gnu.zip -d /opt/rtxvpn_v2/tunnel/
			unzip /opt/rtxvpn_v2/tunnel/tun2socks-linux-amd64.zip -d /opt/rtxvpn_v2/tunnel/
			unzip /opt/rtxvpn_v2/tunnel/Xray-linux-64.zip -d /opt/rtxvpn_v2/tunnel/
			mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-amd64 /opt/rtxvpn_v2/tunnel/tun2socks
			chmod -R +x /opt/rtxvpn_v2/tunnel/
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/tunnel.json
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/tunnel.toml
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/tunnel.py
			;;
		aarch64)
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/FRIMANCS/RTX-VPN/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/FRIMANCS/RTX-VPN/releases/download/v2.5.2/tun2socks-linux-arm64.zip
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/FRIMANCS/RTX-VPN/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
			unzip /opt/rtxvpn_v2/tunnel/rathole-aarch64-unknown-linux-musl.zip -d /opt/rtxvpn_v2/tunnel/
			unzip /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64.zip -d /opt/rtxvpn_v2/tunnel/
			unzip /opt/rtxvpn_v2/tunnel/Xray-linux-arm64-v8a.zip -d /opt/rtxvpn_v2/tunnel/
			mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64 /opt/rtxvpn_v2/tunnel/tun2socks
			chmod -R +x /opt/rtxvpn_v2/tunnel/
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/tunnel.json
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/tunnel.toml
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/FRIMANCS/RTX-VPN/main/configs/tunnel.py
			;;
		*)
			echo "${RED}Unsupported CPU architecture: $CPU_ARCH${NC}"
			exit 1
			;;
	esac
}

tunnel_setup(){
	echo "200 rtx_table" >> /etc/iproute2/rt_tables
	cat <<EOF > /etc/systemd/system/rtxvpn.service
[Unit]
Description=RTX-VPN Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/rtxvpn_v2/tunnel/tunnel.py
ExecStop=/bin/kill -SIGINT $MAINPID
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
	echo 1 > /proc/sys/net/ipv4/ip_forward
	echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
	sysctl -p
	apt install iptables-persistent -y
}

edge_setup(){
	cat <<EOF > /etc/systemd/system/rtxvpn.service
[Unit]
Description=RTX-VPN Edge Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/rtxvpn_v2/edge/edge.py
ExecStop=/bin/kill -SIGINT $MAINPID
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

uuid_tunnel() {
  UUID=$( /opt/rtxvpn_v2/tunnel/xray uuid )
  sed -i "s/\"uuid\"/\"$UUID\"/g" "/opt/rtxvpn_v2/tunnel/tunnel.json"
  sed -i "s/\"uuid\"/\"$UUID\"/g" "/opt/rtxvpn_v2/tunnel/tunnel.toml"
}

uuid_edge() {
  read -p "Enter UUID: " UUID
  read -p "Enter Tunnel IP: " TUNNEL_IP
  sed -i "s/\"uuid\"/\"$UUID\"/g" "/opt/rtxvpn_v2/edge/edge.json"
  sed -i "s/\"uuid\"/\"$UUID\"/g" "/opt/rtxvpn_v2/edge/edge.toml"
  sed -i "s/remote_addr = \".*:[0-9]\+\"/remote_addr = \"$TUNNEL_IP:7081\"/" "/opt/rtxvpn_v2/edge/edge.toml"
}

root_check
clear

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
            uuid_tunnel
            tunnel_setup
            echo "${GREEN}Tunnel installed!${NC} Please Setup the Edge server and enter this UUID: ${GOLD}$UUID${NC}"
            break
            ;;
        2)
            install_check
            download_edge_files
            uuid_edge
            edge_setup
            echo "${GREEN}Edge installed!${NC} Enjoy your ${GOLD}FREEDOM${NC}"
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
