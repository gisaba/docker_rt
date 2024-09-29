#!/bin/bash
clear

echo "
    ____             ____  _                   __    _                 
   / __ \___  ____ _/ / /_(_)___ ___  ___     / /   (_)___  __  ___  __
  / /_/ / _ \/ __  / / __/ / __  __ \/ _ \   / /   / / __ \/ / / / |/_/
 / _, _/  __/ /_/ / / /_/ / / / / / /  __/  / /___/ / / / / /_/ />  <  
/_/ |_|\___/\__,_/_/\__/_/_/ /_/ /_/\___/  /_____/_/_/ /_/\__,_/_/|_|
 
                                                      on Raspberry Pi
"



# Funzione per ottenere l'URL della release più recente
get_latest_release_url() {
    echo "Fetching latest release URL from GitHub..."

    # Ottieni l'URL della release tramite l'API GitHub
    RELEASE_URL=$(curl -s https://api.github.com/repos/antoniopicone/docker_rt/releases/latest | grep "tag_name" | cut -d '"' -f 4)

    if [[ -z "$RELEASE_URL" ]]; then
        echo "Error: Could not fetch release URL."
        exit 1
    fi

    echo "Latest release URL: $RELEASE_URL"
}

check_rpi_version() {

    MODEL=$(cat /proc/cpuinfo | grep "Model" | awk '{print $5}')

}

download_linux_rt() {
    
    # Ottenere l'URL della release più recente
    get_latest_release_url
    check_rpi_version
    
    # Controlla se il modello è Raspberry Pi 4 o 5 e scarica il file corretto
    if [ "$MODEL" = "4" ]; then
        echo "Raspberry Pi 4 detected. Downloading file for Raspberry Pi 4..."
        wget -O linux66_rt.tar.gz https://github.com/antoniopicone/docker_rt/releases/download/$RELEASE_URL/linux66_rt_bcm2711_defconfig.tar.gz
    elif [ "$MODEL" = "5" ]; then
        echo "Raspberry Pi 5 detected. Downloading file for Raspberry Pi 5..."
        wget -O linux66_rt.tar.gz https://github.com/antoniopicone/docker_rt/releases/download/$RELEASE_URL/linux66_rt_bcm2712_defconfig.tar.gz
    else
        echo "Unsupported Raspberry Pi model: $MODEL"
        exit 1
    fi


}


# Spinner function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    tput civis
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\\b\\b\\b\\b\\b\\b"
    done
    printf "    \\b\\b\\b\\b"
    tput cnorm
}

# Function to run commands and show spinner
run_with_spinner() {
    local func="$1"
    local description="$2"

    printf "• %s... " "$description"
    $func > /dev/null 2>&1 &   # Run the function in the background
    pid=$!
    spinner $pid
    wait $pid
    if [ $? -eq 0 ]; then
        printf "\\e[32m✔\\e[0m\\n"  # Green checkmark after success
    else
        printf "\\e[31m✖\\e[0m\\n"  # Red cross after failure
    fi
}

LINUX_KERNEL_VERSION=6.6
LINUX_KERNEL_RT_PATCH=patch-6.6.30-rt30
LINUX_KERNEL_BRANCH=stable_20240529
HW_SPECIFIC_CONFIG=bcm2711_defconfig # Raspberry Pi 4B

update_os() {
    apt-get update
    dpkg --configure -a
    apt-get upgrade -y
    apt-get install -y git wget zip unzip fdisk curl xz-utils bash vim raspi-utils
}

install_rt_kernel() {

    
    tar xzf linux66_rt.tar.gz 

    cd linux

    make -j$(nproc) modules_install

    cp ./arch/arm64/boot/Image /boot/firmware/Image66_rt.img
    cp ./arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
    cp ./arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
    cp ./arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/
    echo "kernel=Image66_rt.img" >> /boot/firmware/config.txt

    # Create cpu device for realtime containers
    mkdir -p /dev/cpu
    mknod /dev/cpu/0 b 5 1

    # Set C0 to avoid idle on CPUs
    sed -i 's/rootwait/rootwait processor.max_cstate=0 intel_idle.max_cstate=0 idle=poll/' /boot/firmware/cmdline.txt
}


# Disable gui
disable_gui() {
    systemctl set-default multi-user.target
}

# Disable power management
disable_power_mgmt() {
    systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

}

# Disable unnecessary services
disable_unnecessary_services() {
    systemctl disable bluetooth
    #systemctl disable avahi-daemon
    systemctl disable irqbalance
    systemctl disable cups
    systemctl disable ModemManage
    systemctl disable triggerhappy
    systemctl disable systemd-timesyncd
    systemctl disable wpa_supplicant
}

# Funzione per installare Docker
install_docker() {
    # Add Docker's official GPG key:
    apt-get update
    apt-get install ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update

    # Aggiorna e installa Docker
    apt update
    apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Abilita Docker al boot
    systemctl enable docker
    
    # Post installation script
    usermod -aG docker $SUDO_USER
}

tune_system_for_realtime() {

    addgroup realtime
    usermod -a -G realtime $SUDO_USER
    tee /etc/security/limits.conf > /dev/null << EOF 
@realtime soft rtprio 99
@realtime soft priority 99
@realtime soft memlock 102400
@realtime hard rtprio 99
@realtime hard priority 99
@realtime hard memlock 102400
EOF

}

enable_ethernet_over_usbc() {

    sed -i 's/rootwait/rootwait modules-load=dwc2,g_ether/' /boot/firmware/cmdline.txt
    sh -c 'echo "dtoverlay=dwc2,dr_mode=peripheral" >> /boot/firmware/config.txt'
    sh -c 'echo "libcomposite" >> /etc/modules'
    sh -c 'echo "denyinterfaces usb0" >> /etc/dhcpcd.conf'

    # Install dnsmasq
    apt-get update
    apt-get install -y dnsmasq
    apt-get clean

    tee /etc/dnsmasq.d/usb > /dev/null << EOF
interface=usb0
dhcp-range=10.55.0.2,10.55.0.6,255.255.255.248,1h
dhcp-option=3
leasefile-ro
EOF

    
    tee /etc/network/interfaces.d/usb0 > /dev/null << EOF
auto usb0
allow-hotplug usb0
iface usb0 inet static
address 10.55.0.1
netmask 255.255.255.248    
EOF
    
    tee /root/usb.sh > /dev/null << EOF
#!/bin/bash
cd /sys/kernel/config/usb_gadget/
mkdir -p pi4
cd pi4
echo 0x1d6b > idVendor # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget
echo 0x0100 > bcdDevice # v1.0.0
echo 0x0200 > bcdUSB # USB2
echo 0xEF > bDeviceClass
echo 0x02 > bDeviceSubClass
echo 0x01 > bDeviceProtocol
mkdir -p strings/0x409
echo "fedcba9876543211" > strings/0x409/serialnumber
echo "Antonio Picone" > strings/0x409/manufacturer
echo "Raspberry PI USB Device" > strings/0x409/product
mkdir -p configs/c.1/strings/0x409
echo "Config 1: ECM network" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower
# Add functions here
# see gadget configurations below
# End functions
mkdir -p functions/ecm.usb0
HOST="00:dc:c8:f7:75:14" # "HostPC"
SELF="00:dd:dc:eb:6d:a1" # "BadUSB"
echo $HOST > functions/ecm.usb0/host_addr
echo $SELF > functions/ecm.usb0/dev_addr
ln -s functions/ecm.usb0 configs/c.1/
udevadm settle -t 5 || :
ls /sys/class/udc > UDC
ifup usb0
service dnsmasq restart
EOF
    chmod +x /root/usb.sh
    sed -i 's|exit 0|/root/usb.sh\nexit 0|' /etc/rc.local

}

cleanup() {

    apt-get remove -y --auto-remove --purge libx11-.*
    apt clean
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
    rm linux66_rt.tar.gz
    rm -rf ./linux
    
}

# Funzione per richiedere all'utente di premere un tasto per il riavvio
request_reboot() {
    echo ""
    echo "All done."
    echo "Please reboot the system and enjoy your realtime kernel!"
    
}


run_with_spinner update_os "Updating OS"
run_with_spinner disable_unnecessary_services "Disabling unnecessary services"
run_with_spinner disable_gui "Disabling GUI"
run_with_spinner disable_power_mgmt "Disabling power management"
run_with_spinner install_docker "Installing Docker"
run_with_spinner download_linux_rt "Downloading pre-built Linux 6.6 Realtime kernel from repository"
run_with_spinner install_rt_kernel "Installing RT kernel (will take some minutes)"
run_with_spinner tune_system_for_realtime "Tuning system for realtime"
run_with_spinner enable_ethernet_over_usbc "Enabling Ethernet over USB-C"
run_with_spinner cleanup "Cleaning up the system"
request_reboot
