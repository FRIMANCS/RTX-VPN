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

# ===== تابع جدید برای هدایت ترافیک WireGuard =====
wg_to_rtx_setup() {
    echo ""
    echo "${CYAN}--- راه‌اندازی هدایت ترافیک WireGuard به تونل RTX ---${NC}"
    read -p "رنج IP WireGuard (مثلا 192.192.192.0/24): " WG_RANGE
    read -p "IP تونل RTX (مثلا 198.19.0.1): " RTX_IP

    echo "${CYAN}فعال‌سازی IP forwarding...${NC}"
    sysctl -w net.ipv4.ip_forward=1
    grep -qxF 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

    echo "${CYAN}ایجاد جدول مسیریابی rtx_table...${NC}"
    grep -q "100 rtx_table" /etc/iproute2/rt_tables || echo "100 rtx_table" >> /etc/iproute2/rt_tables

    echo "${CYAN}ایجاد رابط rtx و فعال کردن آن...${NC}"
    ip link show rtx >/dev/null 2>&1 || ip tuntap add mode tun dev rtx
    ip link set dev rtx up

    echo "${CYAN}اضافه کردن route ها به جدول rtx_table...${NC}"
    ip route add default dev rtx table rtx_table
    ip route add $WG_RANGE dev wg0 table rtx_table

    echo "${CYAN}اضافه کردن قوانین ip rule...${NC}"
    ip rule add from $WG_RANGE table rtx_table priority 100

    echo "${CYAN}تنظیم iptables برای NAT و فورواردینگ...${NC}"
    iptables -A FORWARD -i wg0 -o rtx -j ACCEPT
    iptables -A FORWARD -i rtx -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -t nat -A POSTROUTING -s $WG_RANGE -o rtx -j MASQUERADE

    echo "${GREEN}✅ ترافیک WireGuard ($WG_RANGE) اکنون از تونل RTX ($RTX_IP) عبور می‌کند.${NC}"
    apt install iptables-persistent -y
}
# ===== پایان تابع جدید =====

# ... بقیه توابع اصلی مثل uninstall، download_tunnel_files، download_edge_files، softether_setup، dnsmasq_setup، tunnel_setup، edge_setup، uuid_tunnel، uuid_edge و softether_tip همانند نسخه اصلی شما هستند ...

# ===== منطق اصلی منو =====
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
echo "3.Setup WG->RTX Routing"
echo "4.Uninstall"
echo ""
while true; do
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            install_check
            download_tunnel_files
            softether_setup
            softether_tip
            while true; do
                read -p "Please follow instructions, then type ${CYAN}'verify'${NC} to continue: " confirm
                if [ "$confirm" = "verify" ]; then
                    uuid_tunnel
                    tunnel_setup
                    dnsmasq_setup
                    echo ""
                    echo "${GREEN}Tunnel installed!${NC} Please Setup the Edge server and enter this UUID: ${GOLD}$UUID${NC}"
                    break
                else
                    echo "Please follow instructions, then type ${CYAN}'verify'${NC} to continue: "
                fi
            done
            break
            ;;
        2)
            install_check
            download_edge_files
            uuid_edge
            edge_setup
            echo ""
            echo "${GREEN}Edge installed!${NC} Enjoy your ${GOLD}FREEDOM${NC}"
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
            echo "Invalid option. Please enter 1, 2, 3, or 4."
            ;;
    esac
done
