#!/bin/sh

clear

echo "
    ____             ____  _                   __    _                 
   / __ \___  ____ _/ / /_(_)___ ___  ___     / /   (_)___  __  ___  __
  / /_/ / _ \/ __  / / __/ / __  __ \/ _ \   / /   / / __ \/ / / / |/_/
 / _, _/  __/ /_/ / / /_/ / / / / / /  __/  / /___/ / / / / /_/ />  <  
/_/ |_|\___/\__,_/_/\__/_/_/ /_/ /_/\___/  /_____/_/_/ /_/\__,_/_/|_|
 
                                                      on Raspberry Pi
"

# Handle signals
cleanup_int () {
    echo ""
    echo "Interruzione richiesta. Terminazione del processo."
    if [ -n "$spinner_pid" ]; then
        kill "$spinner_pid" 2>/dev/null  # Uccidi il processo dello spinner
    fi
    if [ -n "$cmd_pid" ]; then
        kill "$cmd_pid" 2>/dev/null  # Uccidi il processo in background
    fi
    tput cnorm  # Ripristina il cursore
    tput rc
	exit 1
	
}

init() {

    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be executed with sudo, exiting :("
        exit 1
    fi

    check_rpi_version

}


check_rpi_version() {
    
    MODEL=$(cat /proc/cpuinfo 2>/dev/null | grep "Model" | awk '{print $5}') 
    if [ "$MODEL" = "4" ] || [ "$MODEL" = "5" ]; then
        echo  "Raspberry Pi $MODEL detected.\n"
    else
        echo "Unsupported device, exiting :(\n"
        exit 1
    fi

}


spinner () {
  local pid=$1
  local delay=0.1
  local symbols="⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏"  
  local colornum=3 # 3=yellow
  local reset=$(tput sgr0)
  local description=$2
  
  while kill -0 $pid 2>/dev/null; do
    tput civis
    for c in $symbols; do
      color=$(tput setaf ${colornum})
      tput sc
      env printf "${color}${c}${reset} ${description}"
      tput rc
      env sleep .1
      if ! kill -0 "$pid" 2>/dev/null; then
        break
      fi  
    done
    tput el
  done
  tput cnorm
  tput rc
  return 0
}

run_with_spinner() {
    # This tries to catch any exit, to reset cursor
    trap cleanup_int INT QUIT TERM
    local func=$1
    local description="$2"
    $func > /dev/null 2>&1 &
    local pid=$!
    spinner $pid "$description"
    wait $pid
    if [ $? -eq 0 ]; then
        printf "\033[32m✔\033[0m %s\n" "$description"
    else
        printf "\033[31m✖\033[0m %s\n" "$description"
    fi
}

update_os() {
    apt-get update
    dpkg --configure -a
    apt-get upgrade -y
    apt-get install -y git wget zip unzip fdisk curl xz-utils bash vim raspi-utils cpufrequtils
}



# Disable gui
disable_gui() {
    systemctl set-default multi-user.target
}

# Disable power management
disable_power_mgmt() {
    systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    echo "IdleAction=ignore" >> /etc/systemd/logind.conf

}

# Disable unnecessary services
disable_unnecessary_services() {
    systemctl disable bluetooth
    #systemctl disable avahi-daemon
    systemctl disable irqbalance
    systemctl disable cups
    systemctl disable ModemManage
    systemctl disable triggerhappy
    # systemctl disable wpa_supplicant
}

# Funzione per installare Docker
install_docker() {
    # Add Docker's official GPG key:
    apt-get update
    apt-get install -y ca-certificates curl
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
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Abilita Docker al boot
    systemctl enable docker
    
    # Post installation script
    usermod -aG docker $SUDO_USER
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


request_reboot() {
    echo ""
    echo "All done."
    echo "Please reboot the system and enjoy your realtime kernel!"
    
}

download_docker_rt_repo() {
    local repo_url="https://github.com/antoniopicone/docker_rt.git"
    local target_dir="docker_rt"

    # Create a temporary file for storing output
    local temp_output=$(mktemp)

    # Clone the repository
    if git clone "$repo_url" "$target_dir" > "$temp_output" 2>&1; then
        echo "Repository downloaded successfully."
    else
        echo "Error downloading repository. Check the log for details."
        cat "$temp_output"
    fi

    # Remove the temporary file
    rm -f "$temp_output"
}

cleanup() {

    readonly KERNEL_SETUP_DIR=$(pwd)
    apt-get -y clean
    rm -rf $KERNEL_SETUP_DIR/linux
    rm -f $KERNEL_SETUP_DIR/linux66_rt.tar.gz 
    
}

get_latest_release_url() {
    echo "Fetching latest release URL from GitHub..."

    # Ottieni la versione della release tramite l'API GitHub
    RELEASE_VER=$(curl -s https://api.github.com/repos/antoniopicone/docker_rt/releases/latest | grep "tag_name" | cut -d '"' -f 4)

    if [[ -z "$RELEASE_VER" ]]; then
        echo "Error: Could not fetch release URL."
        exit 1
    fi

    CONFIG_MODEL="bcm2711"
    # Controlla se il modello è Raspberry Pi 4 o 5 e scarica il file corretto
    if [ "$MODEL" = "5" ]; then
        CONFIG_MODEL="bcm2712"  
    fi

    KERNEL_URL="https://github.com/antoniopicone/docker_rt/releases/download/$RELEASE_VER/linux66_rt_${CONFIG_MODEL}_defconfig.tar.gz"
    
}

install_rt_kernel() {

    get_latest_release_url
    
    wget -O linux66_rt.tar.gz $KERNEL_URL
    
    readonly KERNEL_SETUP_DIR=$(pwd)

    tar xzf linux66_rt.tar.gz 

    cd linux

    make -j$(nproc) modules_install

    cp ./arch/arm64/boot/Image /boot/firmware/Image66_rt_$RELEASE_VER.img
    cp ./arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
    cp ./arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
    cp ./arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/
    echo "kernel=Image66_rt_$RELEASE_VER.img" >> /boot/firmware/config.txt
 
}

tune_system_for_realtime() {

    # Create cpu device for realtime containers
    mkdir -p /dev/cpu
    mknod /dev/cpu/0 b 5 1

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

    echo "consoleblank=0" >> /boot/firmware/config.txt
    echo "force_turbo=1" >> /boot/firmware/config.txt
    echo "arm_freq=1500" >> /boot/firmware/config.txt
    echo "arm_freq_min=1500" >> /boot/firmware/config.txt
    sed -i '1s/^/isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3 /' /boot/firmware/cmdline.txt

    echo " processor.max_cstate=0 intel_idle.max_cstate=0 idle=poll rcu_nocb_poll nohz=on kthread_cpus=0,1 irqaffinity=0,1 iomem=relaxed" >> /boot/firmware/cmdline.txt
    echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
    systemctl disable ondemand
    systemctl enable cpufrequtils

}

generate_htop_config() {
    # Ottenere il nome dell'utente che ha eseguito il comando sudo
    SUDO_USER_HOME=$(eval echo "~$SUDO_USER")
    CONFIG_FILE="$SUDO_USER_HOME/.config/htop/htoprc"
    HTOP_CONFIG_DIR="$SUDO_USER_HOME/.config/htop"

    # Creare la directory di configurazione se non esiste
    if [ ! -d "$HTOP_CONFIG_DIR" ]; then
        mkdir -p "$HTOP_CONFIG_DIR"
        chown "$SUDO_USER":"$SUDO_USER" "$HTOP_CONFIG_DIR"
    fi

    # Creare o sovrascrivere il file di configurazione
    cat <<EOL > "$CONFIG_FILE"
# Beware! This file is rewritten by htop when settings are changed in the interface.
# The parser is also very primitive, and not human-friendly.
htop_version=3.2.2
config_reader_min_version=3
fields=37 114 17 0 48 18 38 39 40 2 46 47 49 17 1
hide_kernel_threads=1
hide_userland_threads=0
hide_running_in_container=0
shadow_other_users=0
show_thread_names=0
show_program_path=1
highlight_base_name=0
highlight_deleted_exe=1
shadow_distribution_path_prefix=0
highlight_megabytes=1
highlight_threads=1
highlight_changes=0
highlight_changes_delay_secs=5
find_comm_in_cmdline=1
strip_exe_from_cmdline=1
show_merged_command=0
header_margin=1
screen_tabs=1
detailed_cpu_time=0
cpu_count_from_one=0
show_cpu_usage=1
show_cpu_frequency=1
show_cpu_temperature=1
degree_fahrenheit=0
update_process_names=0
account_guest_in_cpu_meter=0
color_scheme=0
enable_mouse=1
delay=5
hide_function_bar=0
header_layout=two_50_50
column_meters_0=AllCPUs Memory Swap
column_meter_modes_0=1 1 1
column_meters_1=Tasks LoadAverage Uptime
column_meter_modes_1=2 2 2
tree_view=1
sort_key=46
tree_sort_key=0
sort_direction=-1
tree_sort_direction=1
tree_view_always_by_pid=0
all_branches_collapsed=0
screen:Main=PROCESSOR IO_PRIORITY PRIORITY PID USER NICE M_VIRT M_RESIDENT M_SHARE STATE PERCENT_CPU PERCENT_MEM TIME PRIORITY Command
.sort_key=PERCENT_CPU
.tree_sort_key=PID
.tree_view=1
.tree_view_always_by_pid=0
.sort_direction=-1
.tree_sort_direction=1
.all_branches_collapsed=0
screen:I/O=PID USER IO_PRIORITY IO_RATE IO_READ_RATE IO_WRITE_RATE PERCENT_SWAP_DELAY PERCENT_IO_DELAY Command
.sort_key=IO_RATE
.tree_sort_key=PID
.tree_view=0
.tree_view_always_by_pid=0
.sort_direction=-1
.tree_sort_direction=1
.all_branches_collapsed=0
EOL

    # Impostare il proprietario corretto del file di configurazione
    chown "$SUDO_USER":"$SUDO_USER" "$CONFIG_FILE"
    echo "Il file di configurazione di htop è stato generato/sostituito per l'utente $SUDO_USER."
}

init
run_with_spinner update_os "Updating OS"
run_with_spinner disable_unnecessary_services "Disabling unnecessary services"
run_with_spinner disable_gui "Disabling GUI"
run_with_spinner disable_power_mgmt "Disabling power management"
run_with_spinner install_docker "Installing Docker"
if [ "$MODEL" = "4" ]; then
    run_with_spinner enable_ethernet_over_usbc "Enabling Ethernet over USB-C"
fi
run_with_spinner install_rt_kernel "Installing latest real time kernel (will take some minutes)"
run_with_spinner tune_system_for_realtime "Tuning system for realtime"
run_with_spinner download_docker_rt_repo "Downloading docker_rt repository for local testing"
run_with_spinner generate_htop_config "Changing htop settings to show processors"
run_with_spinner cleanup "Cleaning up the system"
request_reboot

