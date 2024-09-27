#!/bin/bash

LINUX_KERNEL_VERSION=6.6
LINUX_KERNEL_RT_PATCH=patch-6.6.30-rt30
LINUX_KERNEL_BRANCH=stable_20240529
HW_SPECIFIC_CONFIG=bcm2711_defconfig # Raspberry Pi 4B

update_os() {
    apt-get update
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
    systemctl disable cups
    systemctl disable ModemManager
    systemctl disable triggerhappy
    systemctl disable systemd-timesyncd
    systemctl disable wpa_supplicant
}

# Funzione per installare Docker
install_docker() {
    # Installare le dipendenze di Docker
    apt update
    apt install -y apt-transport-https ca-certificates curl software-properties-common

    # Aggiungi la chiave GPG di Docker e il repository ufficiale
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=armhf signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list

    # Aggiorna e installa Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io

    # Abilita Docker al boot
    systemctl enable docker
    
    # Post installation script
    usermod -aG docker $USER

    

}

tune_system_for_realtime() {

    addgroup realtime
    usermod -a -G realtime $USER
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
}


update_os
disable_unnecessary_services
disable_gui
disable_power_mgmt
install_docker
install_rt_kernel
tune_system_for_realtime
enable_ethernet_over_usbc
cleanup