#!/bin/sh

OUTPUT=$(sfdisk -lJ ${RASPIOS})
BOOT_START=$(echo $OUTPUT | jq -r '.partitiontable.partitions[0].start')
BOOT_SIZE=$(echo $OUTPUT | jq -r '.partitiontable.partitions[0].size')
EXT4_START=$(echo $OUTPUT | jq -r '.partitiontable.partitions[1].start')

# Funzioni di helper
disable_unnecessary_services() {
    systemctl disable bluetooth
    #systemctl disable avahi-daemon
    systemctl disable cups
    systemctl disable ModemManager
    systemctl disable triggerhappy
    systemctl disable systemd-timesyncd
    #systemctl disable wpa_supplicant
}

# Funzione per installare Docker
install_docker() {
    # Installare le dipendenze di Docker
    apt update
    apt install -y apt-transport-https ca-certificates curl software-properties-common

    # Aggiungi la chiave GPG di Docker e il repository ufficiale
    #curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    #echo "deb [arch=armhf signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Aggiorna e installa Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io

    # Abilita Docker al boot
    systemctl enable docker
}

# Funzione per abilitare l'utente Docker
configure_docker_user() {
    # Crea l'utente pi (se non esiste)
    if ! id -u pi > /dev/null 2>&1; then
        useradd -m -s /bin/bash pi
    fi

    # Aggiungi l'utente pi al gruppo docker
    usermod -aG docker pi
}



mount -t ext4 -o loop,offset=$(($EXT4_START*512)) ${RASPIOS} /raspios/mnt/disk
mount -t vfat -o loop,offset=$(($BOOT_START*512)),sizelimit=$(($BOOT_SIZE*512)) ${RASPIOS} /raspios/mnt/boot/firmware

cd /rpi-kernel/linux/
make INSTALL_MOD_PATH=/raspios/mnt/disk modules_install
make INSTALL_DTBS_PATH=/raspios/mnt/boot/firmware dtbs_install
cd -

if [ "$ARCH" = "arm64" ]; then
    echo "arm_64bit=1" >> /raspios/config.txt
    cp /rpi-kernel/linux/arch/arm64/boot/Image.gz /raspios/mnt/boot/firmware/$KERNEL\_rt.img
    cp /rpi-kernel/linux/arch/arm64/boot/dts/broadcom/*.dtb /raspios/mnt/boot/firmware/
    cp /rpi-kernel/linux/arch/arm64/boot/dts/overlays/*.dtb* /raspios/mnt/boot/firmware/overlays/
    cp /rpi-kernel/linux/arch/arm64/boot/dts/overlays/README /raspios/mnt/boot/firmware/overlays/
elif [ "$ARCH" = "arm" ]; then
    echo "arm_64bit=0" >> /raspios/config.txt
    cp /rpi-kernel/linux/arch/arm/boot/zImage /raspios/mnt/boot/firmware/$KERNEL\_rt.img
    cp /rpi-kernel/linux/arch/arm/boot/dts/broadcom/*.dtb /raspios/mnt/boot/firmware/
    cp /rpi-kernel/linux/arch/arm/boot/dts/overlays/*.dtb* /raspios/mnt/boot/firmware/overlays/
    cp /rpi-kernel/linux/arch/arm/boot/dts/overlays/README /raspios/mnt/boot/firmware/overlays/
fi

echo "kernel=${KERNEL}_rt.img" >> /raspios/config.txt
cp /raspios/config.txt /raspios/mnt/boot/firmware/
cp /raspios/userconf /raspios/mnt/boot/firmware/
touch /raspios/mnt/boot/firmware/ssh


mount --bind /proc /raspios/mnt/proc
mount --bind /sys /raspios/mnt/sys
mount --bind /dev /raspios/mnt/dev

# esegui funzioni di helper
# Disabilita i servizi non necessari
disable_unnecessary_services

# Installa Docker
install_docker

# Configura l'utente per Docker
configure_docker_user

# Pulizia del sistema per ridurre la dimensione dell'immagine
apt clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


umount /raspios/mnt/disk
umount /raspios/mnt/boot/firmware
umount /raspios/mnt/proc
umount /raspios/mnt/sys
umount /raspios/mnt/dev

mkdir build
zip build/${RASPIOS}-${TARGET}.zip ${RASPIOS}
