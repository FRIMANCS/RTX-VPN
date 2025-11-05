#!/bin/bash
#MmD
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
            read -p "This will remove RTX-VPN v2 (Tunnel) and its associated files. Are you sure? (y/n): " confirm

            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then

                echo "Uninstalling RTX-VPN v2 (Tunnel)..."

                rm -rf /opt/rtxvpn_v2/tunnel

                # ask dynamic
                read -p "Enter WireGuard interface (e.g. wg0): " WG_IFACE
                read -p "Enter tunnel IP range (e.g. 192.192.192.0/24): " TUN_RANGE

                # remove rtx interface
                ip link set dev rtx down 2>/dev/null
                ip tuntap del mode tun dev rtx 2>/dev/null

                # remove routing
                ip rule del from $TUN_RANGE table rtx_table 2>/dev/null
                ip route flush table rtx_table 2>/dev/null

                # remove rules
                iptables -D FORWARD -i $WG_IFACE -o rtx -j ACCEPT 2>/dev/null
                iptables -D FORWARD -i rtx -o $WG_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
                iptables -t nat -D POSTROUTING -s $TUN_RANGE -o rtx -j MASQUERADE 2>/dev/null

                # remove table id
                sed -i '/rtx_table/d' /etc/iproute2/rt_tables

                # remove service
                if [ -f "/etc/systemd/system/rtxvpn.service" ]; then
                    systemctl stop rtxvpn.service
                    systemctl disable rtxvpn.service
                    rm -f /etc/systemd/system/rtxvpn.service
                fi

                echo "Tunnel removed."
                break

            elif [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
                echo "Canceled."
                break
            else
                echo "Invalid input, only y or n."
            fi
        done
    fi


    if [ -d "/opt/rtxvpn_v2/edge" ]; then
        while true; do
            read -p "This will remove RTX-VPN v2 (Edge). Are you sure? (y/n): " confirm

            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                rm -rf /opt/rtxvpn_v2/edge

                if [ -f "/etc/systemd/system/rtxvpn.service" ]; then
                    systemctl stop rtxvpn.service
                    systemctl disable rtxvpn.service
                    rm -f /etc/systemd/system/rtxvpn.service
                fi

                echo "Edge removed."
                break
            elif [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
                echo "Canceled."
                break
            else
                echo "Invalid input."
            fi
        done
    else
        echo "RTX-VPN is not installed."
    fi
}


download_edge_files(){
	apt update && apt install tar sudo wget unzip python3 -y
	
    if [ ! -d "/opt/rtxvpn_v2/edge" ]; then
        mkdir -p /opt/rtxvpn_v2/edge || { echo -e "${RED}Failed to create /opt/rtxvpn_v2/edge directory!${NC}"; exit 1; }
    fi

    CPU_ARCH=$(uname -m)
    case $CPU_ARCH in
        "x86_64")
			
			wget -P /opt/rtxvpn_v2/edge https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
			wget -P /opt/rtxvpn_v2/edge https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
			
			#Extract
			unzip /opt/rtxvpn_v2/edge/rathole-x86_64-unknown-linux-gnu.zip -d /opt/rtxvpn_v2/edge
			unzip /opt/rtxvpn_v2/edge/Xray-linux-64.zip -d /opt/rtxvpn_v2/edge
			
			#Configs
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.json
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.toml
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.py
			
			chmod -R +x /opt/rtxvpn_v2/edge/ 
            ;;
        "aarch64")
			wget -P /opt/rtxvpn_v2/edge/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
			wget -P /opt/rtxvpn_v2/edge/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
			
			#Extract
			unzip /opt/rtxvpn_v2/edge/rathole-aarch64-unknown-linux-musl.zip -d /opt/rtxvpn_v2/edge/
			unzip /opt/rtxvpn_v2/edge/Xray-linux-arm64-v8a.zip -d /opt/rtxvpn_v2/edge/
			
			#Configs
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.json
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.toml
			wget -P /opt/rtxvpn_v2/edge/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/edge.py
			
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
	
    if [ ! -d "/opt/rtxvpn_v2/tunnel/" ]; then
        mkdir -p /opt/rtxvpn_v2/tunnel/ || { echo -e "${RED}Failed to create /opt/rtxvpn_v2/tunnel/ directory!${NC}"; exit 1; }
    fi
    CPU_ARCH=$(uname -m)
    case $CPU_ARCH in
        "x86_64")
			
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-amd64.zip
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
			
			#Extract
			unzip /opt/rtxvpn_v2/tunnel/rathole-x86_64-unknown-linux-gnu.zip -d /opt/rtxvpn_v2/tunnel/
			unzip /opt/rtxvpn_v2/tunnel/tun2socks-linux-amd64.zip -d /opt/rtxvpn_v2/tunnel/
			unzip /opt/rtxvpn_v2/tunnel/Xray-linux-64.zip -d /opt/rtxvpn_v2/tunnel/
			
			#Configs
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.json
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.toml
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.py
			
			mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-amd64 /opt/rtxvpn_v2/tunnel/tun2socks
			chmod -R +x /opt/rtxvpn_v2/tunnel/ 
            ;;
        "aarch64")
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-arm64.zip
			wget -P /opt/rtxvpn_v2/tunnel/ https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-arm64-v8a.zip
			
			#Extract
			unzip /opt/rtxvpn_v2/tunnel/rathole-aarch64-unknown-linux-musl.zip -d /opt/rtxvpn_v2/tunnel/
			unzip /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64.zip -d /opt/rtxvpn_v2/tunnel/
			unzip /opt/rtxvpn_v2/tunnel/Xray-linux-arm64-v8a.zip -d /opt/rtxvpn_v2/tunnel/
			
			#Configs
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.json
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.toml
			wget -P /opt/rtxvpn_v2/tunnel/ https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/configs/tunnel.py
			
			mv /opt/rtxvpn_v2/tunnel/tun2socks-linux-arm64 /opt/rtxvpn_v2/tunnel/tun2socks
			chmod -R +x /opt/rtxvpn_v2/tunnel/
            ;;
        *)
            echo "${RED}Unsupported CPU architecture: $CPU_ARCH${NC}"
            exit 1
            ;;
    esac
}

dnsmasq_setup(){
    mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
	cat <<EOF > /etc/dnsmasq.conf
interface=tap_softether
dhcp-range=tap_softether,198.19.0.2,198.19.0.254,12h
dhcp-option=tap_softether,3,198.19.0.1
dhcp-option=tap_softether,6,8.8.8.8,8.8.4.4
EOF
	systemctl enable dnsmasq
	systemctl restart dnsmasq
}

tunnel_setup(){
    # 🔹 دریافت اطلاعات از کاربر
    read -p "Enter WireGuard interface (e.g., wg0): " WG_IFACE
    read -p "Enter the IP range used in your tunnel (e.g., 192.192.192.0/24): " TUNNEL_IP_RANGE

    # 🔹 فعال‌سازی IP forwarding
    sysctl -w net.ipv4.ip_forward=1
    grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

    # 🔹 حذف رابط‌های قدیمی و جدول‌های قدیمی
    ip link set dev rtx down 2>/dev/null
    ip tuntap del mode tun dev rtx 2>/dev/null

    # حذف قوانین ip rule قدیمی
    ip rule del from $TUNNEL_IP_RANGE table rtx_table 2>/dev/null

    # حذف مسیرهای قدیمی
    ip route flush table rtx_table 2>/dev/null

    # 🔹 ایجاد جدول مسیریابی جدید
    grep -q "100 rtx_table" /etc/iproute2/rt_tables || echo "100 rtx_table" >> /etc/iproute2/rt_tables

    # 🔹 ایجاد رابط جدید و اضافه کردن مسیرها
    ip tuntap add mode tun dev rtx
    ip link set dev rtx up
    ip route add default dev rtx table rtx_table
    ip route add $TUNNEL_IP_RANGE dev $WG_IFACE table rtx_table

    # 🔹 اضافه کردن قانون استفاده از جدول rtx_table
    ip rule add from $TUNNEL_IP_RANGE table rtx_table priority 100

    # 🔹 تنظیم iptables برای NAT و فورواردینگ
    iptables -A FORWARD -i $WG_IFACE -o rtx -j ACCEPT
    iptables -A FORWARD -i rtx -o $WG_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -t nat -A POSTROUTING -s $TUNNEL_IP_RANGE -o rtx -j MASQUERADE

    # 🔹 ایجاد سرویس systemd برای RTX-VPN
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

    echo "✅ Tunnel installed! Traffic from $WG_IFACE will now pass through the RTX tunnel."
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
echo ""
echo "${GREEN}  _____ _________   __  __      _______  _   _    "
echo " |  __ \__   __\ \ / /  \ \    / /  __ \| \ | |   ${NC}"
echo " | |__) | | |   \ V /${GOLD}____${NC}\ \  / /| |__) |  \| |   "
echo " |  _  /  | |    > <${GOLD}______${NC}\ \/ / |  ___/| .   |   ${RED}"
echo " | | \ \  | |   / . \      \  /  | |    | |\  |   "
echo " |_|  \_\ |_|  /_/ \_\  ${GOLD}V2${RED}  \/   |_|    |_| \_|   ${NC}"
echo "                        _                         "               
echo "                      _| |_                       "
echo "                     |_   _|                      "
echo "                       |_|                        "  
echo "${CYAN}   _____        __ _   ______ _   _               "               
echo "  / ____|      / _| | |  ____| | | |              "            
echo " | (___   ___ | |_| |_| |__  | |_| |__   ___ _ __ "
echo "  \___ \ / _ \|  _| __|  __| | __| '_ \ / _ \ '__|"
echo "  ____) | (_) | | | |_| |____| |_| | | |  __/ |   "
echo " |_____/ \___/|_|  \__|______|\__|_| |_|\___|_|   ${NC}"
echo "" 
echo ""
echo "Choose an option:"
echo ""
echo "1.Setup Tunnel"
echo "2.Setup Edge"
echo "3.Uninstall"
echo ""
while true; do
    read -p "Enter your choice (1, 2 or 3): " choice
    
    case $choice in
        1)
			install_check
			download_tunnel_files
            uuid_tunnel
			tunnel_setup
			dnsmasq_setup
			echo ""
			echo ""
			echo "${GREEN}Tunnel installed!${NC} Please Setup the Edge server and enter this UUID: ${GOLD}$UUID${NC}"
 			echo ""
  			echo "You can use these commands to check RTX-VPN status:"
    			echo "${CYAN}systemctl status rtxvpn${NC}"
    			echo "${CYAN}systemctl status dnsmasq${NC}"
   			echo ""
	   		echo ""
            break
            ;;
        2)
			install_check
			download_edge_files
			uuid_edge
			edge_setup
			echo ""
			echo ""
			echo "${GREEN}Edge installed!${NC} Enjoy your ${GOLD}FREEDOM${NC}"
 			echo ""
			echo "You can use this command to check RTX-VPN status: ${CYAN}systemctl status rtxvpn${NC}"
   			echo ""
   			echo ""
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
