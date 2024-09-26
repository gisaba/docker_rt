#!/bin/bash


# Disable gui
disable_gui() {
    systemctl set-default multi-user.target
}

# Disable power management
disable_power_mgmt() {
    systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

}


# Funzione per disabilitare i servizi non necessari
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
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=armhf signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list

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

# Disabilita i servizi non necessari
disable_unnecessary_services
disable_gui
disable_power_mgmt

# Installa Docker
install_docker

# Configura l'utente per Docker
configure_docker_user

# Pulizia del sistema per ridurre la dimensione dell'immagine
apt clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*