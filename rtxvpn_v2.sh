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
            read -p "This will remove ${CYAN}RTX-VPN v2 (Tunnel)${NC} and its associated files. Are you sure? (y/n): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                echo "Uninstalling RTX-VPN v2 (Tunnel)..."
                rm -rf "/opt/rtxvpn_v2/tunnel"
				
				systemctl stop dnsmasq
				systemctl disable dnsmasq
				
                apt remove dnsmasq -y
				
                sed -i '/200 rtx_table/d' /etc/iproute2/rt_tables
				ip link set dev rtx down
				ip tuntap del mode tun dev rtx
				ip link set dev tap_softether down
				ip addr del 198.19.0.1/24 dev tap_softether
				ip route del 198.19.0.0/24 dev rtx table rtx_table
				ip route del default dev rtx table rtx_table
				ip rule del from 198.19.0.0/24 table rtx_table priority 10
				ip rule del to 8.8.8.8 table main priority 11
				ip rule del to 8.8.4.4 table main priority 12
				
				iptables -D FORWARD -i tap_softether -o rtx -j ACCEPT
				iptables -D FORWARD -i rtx -o tap_softether -m state --state ESTABLISHED,RELATED -j ACCEPT
				netfilter-persistent save
				
                if [ -f "/etc/systemd/system/rtxvpn.service" ]; then
                    systemctl stop rtxvpn.service
                    systemctl disable rtxvpn.service
                    rm -f /etc/systemd/system/rtxvpn.service
                    echo "RTX-VPN service ${GREEN}removed${NC}"
                else
                    echo "RTX-VPN service ${RED}not found!${NC}"
                fi

                echo "RTX-VPN v2 (Tunnel) has been ${GREEN}removed${NC}"
                break
            elif [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
                echo "Uninstallation of RTX-VPN v2 (Tunnel) ${RED}canceled${NC}"
                break
            else
                echo "Invalid input. Please enter 'y' for yes or 'n' for no."
            fi
        done
    fi

    # Check and remove the edge directory
    if [ -d "/opt/rtxvpn_v2/edge" ]; then
        while true; do
            read -p "This will remove ${CYAN}RTX-VPN v2 (Edge)${NC} and its associated files. Are you sure? (y/n): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                echo "Uninstalling RTX-VPN v2 (Edge)..."
                rm -rf "/opt/rtxvpn_v2/edge"
                
                # Remove RTX-VPN service
                if [ -f "/etc/systemd/system/rtxvpn.service" ]; then
                    systemctl stop rtxvpn.service
                    systemctl disable rtxvpn.service
                    rm -f /etc/systemd/system/rtxvpn.service
                    echo "RTX-VPN service ${GREEN}removed${NC}"
                else
                    echo "RTX-VPN service ${RED}not found!${NC}"
                fi
                
                echo "RTX-VPN v2 (Edge) has been ${GREEN}removed${NC}"
                break
            elif [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
                echo "Uninstallation of RTX-VPN v2 (Edge) ${RED}canceled${NC}"
                break
            else
                echo "Invalid input. Please enter 'y' for yes or 'n' for no."
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
	iptables -A FORWARD -i tap_softether -o rtx -j ACCEPT
	iptables -A FORWARD -i rtx -o tap_softether -m state --state ESTABLISHED,RELATED -j ACCEPT

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
