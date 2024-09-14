#!/bin/bash

# Nome dello script: build-debian-live.sh
# Descrizione: Script per generare una ISO live Debian personalizzata
# Autore: Antonio Picone
# Data: Settembre 2024

set -e

# Colori per l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # Nessun colore

# Variabili
DISTRO="bookworm"  # Cambia con la versione di Debian desiderata (es: bullseye per Debian 11)
ARCHIVE_AREAS="main contrib non-free non-free-firmware"
IMAGE_NAME="custom-debian-live.iso"

# Variabili per i task
TASKS=(
    "Pulizia dell'ambiente"
    "Installazione dei pacchetti necessari"
    "Configurazione di live-build"
    "Aggiunta della lista dei pacchetti"
    "Configurazione dei repository non-free"
    "Aggiunta dei pacchetti firmware"
    "Richiesta delle credenziali utente"
    "Creazione dell'utente personalizzato"
    "Aggiunta del repository Docker e installazione"
    "Costruzione dell'immagine ISO"
)
TASK_STATUS=()
for ((i=0; i<${#TASKS[@]}; i++)); do
    TASK_STATUS[i]=0
done

# Funzione per stampare lo stato dei task
print_tasks() {
    clear
    echo "Progressione dei task:"
    for ((i=0; i<${#TASKS[@]}; i++)); do
        if [ ${TASK_STATUS[i]} -eq 1 ]; then
            echo -e "[${GREEN}✔${NC}] ${TASKS[i]}"
        else
            echo -e "[ ] ${TASKS[i]}"
        fi
    done
}

# Funzione per aggiornare lo stato di un task
update_task() {
    TASK_STATUS[$1]=1
    print_tasks
}

# Funzione per pulire l'ambiente
clean_environment() {
    print_tasks
    sudo lb clean > /dev/null 2>&1
    sudo rm -rf config auto chroot binary > /dev/null 2>&1
    update_task 0
}

# Funzione per installare i pacchetti necessari
install_dependencies() {
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y live-build ca-certificates curl gnupg > /dev/null 2>&1
    update_task 1
}

# Funzione per configurare live-build
configure_live_build() {
    lb config \
        --distribution "$DISTRO" \
        --archive-areas "$ARCHIVE_AREAS" \
        --binary-images iso-hybrid \
        --debian-installer false \
        --bootappend-live "boot=live components" \
        --apt-recommends false \
        --iso-application "Custom Debian RT w/Docker Live" \
        --iso-publisher "Antonio Picone <info@antoniopicone.it>" \
        --iso-preparer "Antonio Picone <info@antoniopicone.it>" \
        --iso-volume "Custom Debian RT w/Docker Live" \
        --image-name "$IMAGE_NAME" > /dev/null 2>&1
    update_task 2
}

# Funzione per aggiungere la lista dei pacchetti
add_package_lists() {
    mkdir -p config/package-lists
    cat <<EOL > config/package-lists/custom.list.chroot
linux-image-rt-amd64
openssh-server
vim
avahi-daemon
EOL
    update_task 3
}

# Funzione per configurare i repository non-free e non-free-firmware
configure_non_free() {
    mkdir -p config/archives
    cat <<EOL > config/archives/extra.list.chroot
deb http://deb.debian.org/debian $DISTRO main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $DISTRO-security main contrib non-free non-free-firmware
EOL
    update_task 4
}

# Funzione per aggiungere il firmware necessario
add_firmware() {
    mkdir -p config/package-lists
    echo "firmware-linux" > config/package-lists/firmware.list.chroot
    update_task 5
}

# Funzione per richiedere le credenziali utente
ask_user_credentials() {
    echo "Inserisci il nome utente desiderato per la live ISO:"
    read -p "Username: " CUSTOM_USERNAME
    while true; do
        read -s -p "Password per $CUSTOM_USERNAME: " CUSTOM_PASSWORD
        echo
        read -s -p "Conferma password: " CUSTOM_PASSWORD_CONFIRM
        echo
        [ "$CUSTOM_PASSWORD" = "$CUSTOM_PASSWORD_CONFIRM" ] && break
        echo -e "${RED}Le password non coincidono. Riprova.${NC}"
    done

    while true; do
        read -s -p "Password per l'utente root: " ROOT_PASSWORD
        echo
        read -s -p "Conferma password root: " ROOT_PASSWORD_CONFIRM
        echo
        [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ] && break
        echo -e "${RED}Le password non coincidono. Riprova.${NC}"
    done
    update_task 6
}

# Funzione per creare un utente personalizzato
create_custom_user() {
    mkdir -p config/hooks
    cat <<EOL > config/hooks/0200-create-user.chroot
#!/bin/bash
set -e

# Imposta la password di root
echo "root:$ROOT_PASSWORD" | chpasswd

# Crea l'utente personalizzato
useradd -m -s /bin/bash $CUSTOM_USERNAME
echo "$CUSTOM_USERNAME:$CUSTOM_PASSWORD" | chpasswd

# Aggiungi l'utente ai gruppi sudo e docker
apt-get install -y sudo > /dev/null 2>&1
usermod -aG sudo $CUSTOM_USERNAME
usermod -aG docker $CUSTOM_USERNAME

EOL
    chmod +x config/hooks/0200-create-user.chroot
    update_task 7
}

# Funzione per aggiungere il repository Docker e installare Docker
add_docker_repo() {
    mkdir -p config/hooks
    cat <<'EOL' > config/hooks/0100-docker-repo.chroot
#!/bin/bash
set -e

# Install prerequisites
apt-get update > /dev/null 2>&1
apt-get install -y ca-certificates curl gnupg lsb-release > /dev/null 2>&1

# Add Docker’s official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  bullseye stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update > /dev/null 2>&1

# Install Docker packages
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1

# Enable Docker service
systemctl enable docker

EOL
    chmod +x config/hooks/0100-docker-repo.chroot
    update_task 8
}

# Funzione per costruire l'immagine con spinner
build_image() {
    # Avvia lb build in background
    sudo lb build > /dev/null 2>&1 &
    LB_BUILD_PID=$!

    # Spinner
    i=0
    sp='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    echo -n "Costruzione dell'immagine ISO in corso... "
    while kill -0 $LB_BUILD_PID 2> /dev/null; do
        printf "\b${sp:i++%${#sp}:1}"
        sleep 0.1
    done
    echo -e "\b${GREEN}✔${NC}"
    update_task 9
    echo -e "${GREEN}Tutti i task completati con successo!${NC}"
    echo "Immagine ISO generata: ${IMAGE_NAME}"
}

# Funzione principale
main() {
    print_tasks
    clean_environment
    install_dependencies
    configure_live_build
    add_package_lists
    configure_non_free
    add_firmware
    ask_user_credentials
    create_custom_user
    add_docker_repo
    build_image
}

# Esegui la funzione principale
main