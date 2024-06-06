#!/bin/bash

# Ensure the script is run as root and set up logging
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Detect the operating system and version
. /etc/os-release

# Log file location
LOG_FILE="/var/log/setup_server.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Logging functions
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" | tee -a "$LOG_FILE" >&2
}

# Function to check and fix interrupted dpkg if necessary (Debian-based systems)
check_dpkg() {
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    if ! sudo dpkg --audit >/dev/null; then
        log_warning "dpkg was interrupted. Attempting to correct this..."
        if sudo dpkg --configure -a; then
            log_info "dpkg configuration issues resolved."
        else
            log_error "Failed to correct dpkg configuration."
            exit 1
        fi
    fi
    fi
}

log_info "Script execution started."

# Function to get USERID, KEY, and SSH keys URL from environment variables or user input
get_credentials() {
    USERID="${1:-$USERID}"
    KEY="${2:-$KEY}"
    SSH_KEYS_URL="${3:-https://github.com/yashodhank.keys}" # Default to your GitHub keys

    if [ -z "$USERID" ]; then
        read -p "Enter USERID: " USERID
        log_info "USERID provided by user input."
    fi
    if [ -z "$KEY" ]; then
        read -p "Enter KEY: " KEY
        log_info "KEY provided by user input."
    fi
    log_info "Using SSH keys from: $SSH_KEYS_URL"
}

# Function to set system timezone with support for environment variable or user input
set_timezone() {
    local default_tz="Asia/Kolkata"
    local tz="${TIMEZONE:-$default_tz}"

    log_info "Checking system timezone settings."

    if [ -z "$TIMEZONE" ]; then
        echo -n "Enter the timezone (or press Enter to use '$default_tz'): "
        read user_tz
        tz="${user_tz:-$default_tz}"
        log_info "Timezone set by user input or default: $tz."
    fi

    # Get and set the current system timezone
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
    local current_tz=$(timedatectl show --value --property Timezone)

    # Check if the desired timezone matches the current timezone
    if [ "$current_tz" != "$tz" ]; then
        if timedatectl set-timezone "$tz"; then
            log_info "Timezone changed to $tz."
        else
            log_error "Failed to set timezone to $tz. Please ensure it's a valid timezone."
        fi
    else
        log_info "Timezone already set to $tz."
        fi
    elif [[ "$ID" == "almalinux" || "$ID" == "rocky" || "$ID" == "centos" ]]; then
        local current_tz=$(cat /etc/timezone)
        if [ "$current_tz" != "$tz" ]; then
            echo "$tz" > /etc/timezone
            ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
            log_info "Timezone changed to $tz."
        else
            log_info "Timezone already set to $tz."
        fi
    fi
}

# Function to update system and install required packages
update_system() {
    export DEBIAN_FRONTEND=noninteractive
    log_info "Updating system and installing required packages..."
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
    check_dpkg

    if ! output=$(apt-get update -qq 2>&1); then
        log_error "Failed to update package lists. Error: $output"
        return 1
    else
        log_info "System update completed."
    fi

    if ! output=$(apt-get upgrade -y -qq 2>&1); then
            log_error "Failed to upgrade system. Error: $output"
        return 1
    fi
    elif [[ "$ID" == "almalinux" || "$ID" == "rocky" || "$ID" == "centos" ]]; then
        if ! output=$(yum update -y -q 2>&1); then
            log_error "Failed to update package lists. Error: $output"
            return 1
        fi
    fi

    # Define all packages
    local pkgs=(git sudo curl wget nano htop tmux screen unzip zip rsync tree net-tools ufw jq ncdu nmap telnet mtr iputils-ping tcpdump traceroute bind9-dnsutils whois sysstat iotop iftop vnstat glances snapd software-properties-common sshguard rkhunter mc lsof strace dstat iperf3 ntp build-essential python3-pip)
    local pkg_manager="apt-get"
    local install_cmd="-y -qq install"

    if [[ "$ID" == "almalinux" || "$ID" == "rocky" || "$ID" == "centos" ]]; then
        pkg_manager="yum"
        install_cmd="-y install"
        pkgs=(git sudo curl wget nano htop tmux screen unzip zip rsync tree net-tools firewalld jq ncdu nmap telnet mtr iputils tcpdump traceroute bind-utils whois sysstat iotop iftop vnstat glances snapd sshguard rkhunter mc lsof strace dstat iperf ntp-devel make automake gcc gcc-c++ kernel-devel python3-pip)
    fi

    # Install all required packages at once
    if ! output=$($pkg_manager $install_cmd ${pkgs[*]} 2>&1); then
            log_error "Failed to install required packages. Error: $output"
        return 1
    else
        log_info "All required packages installed successfully."
    fi
}

# Function to install Docker using the official Docker convenience script
install_docker() {
    export DEBIAN_FRONTEND=noninteractive
    log_info "Checking Docker installation..."
    if ! command -v docker >/dev/null 2>&1; then
        log_info "Installing Docker using the official Docker installation script..."
        if curl -fsSL https://get.docker.com -o get-docker.sh; then
            if sudo sh get-docker.sh; then
                log_info "Docker installed successfully."
            else
                log_error "Failed to install Docker."
            fi
        else
            log_error "Failed to download the Docker installation script."
        fi
    else
        log_info "Docker is already installed."
    fi
}

# Function to install NERD Fonts
install_fonts() {
    log_info "Installing NERD Fonts..."
    local fonts=("Hack/Regular/HackNerdFont-Regular.ttf"
                 "RobotoMono/Regular/RobotoMonoNerdFont-Regular.ttf"
                 "SourceCodePro/SauceCodeProNerdFont-Regular.ttf"
                 "AnonymousPro/Regular/AnonymiceProNerdFont-Regular.ttf"
                 "FiraCode/Regular/FiraCodeNerdFont-Regular.ttf"
                 "iA-Writer/Mono/Regular/iMWritingMonoNerdFont-Regular.ttf")
    mkdir -p /usr/local/share/fonts
    for font in "${fonts[@]}"; do
        local filename="/usr/local/share/fonts/${font##*/}"
        if [ ! -f "$filename" ]; then
            log_info "Downloading $font..."
            if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/$font" -o "$filename"; then
                log_info "$filename downloaded successfully."
            else
                log_error "Failed to download $font."
            fi
        else
            log_info "$filename is already installed."
        fi
    done
}

# Function to install and configure Starship prompt for all current and future users
setup_starship() {
    log_info "Setting up Starship for all current and future users..."
    if ! command -v starship >/dev/null 2>&1; then
        log_info "Installing Starship..."
        if curl -fsSL https://starship.rs/install.sh | sh -s -- -y; then
            log_info "Starship installed successfully."
        else
            log_error "Failed to install Starship."
            return 1
        fi
    fi

    # Apply the Starship configuration to all users
    local config_url="https://gist.githubusercontent.com/yashodhank/0343daac9c8950bc63ffb9263043e345/raw/starship.toml"
    mkdir -p /etc/skel/.config
    if curl -fsSL "$config_url" -o /etc/skel/.config/starship.toml; then
        log_info "Starship configuration downloaded successfully."
    else
        log_error "Failed to download the Starship configuration."
        return 1
    fi

    # Apply the configuration to all existing users
        getent passwd | while IFS=: read -r name _ uid gid _ home shell; do
            if [ "$uid" -ge 1000 ] && [ -d "$home" ] && [[ "$shell" == *"/bash" ]]; then
            local config_dir="$home/.config"
            mkdir -p "$config_dir"
            cp /etc/skel/.config/starship.toml "$config_dir/starship.toml"

            # Make sure to source Starship in .bashrc
                if ! grep -q 'starship init bash' "$home/.bashrc"; then
                    echo 'eval "$(starship init bash)"' >> "$home/.bashrc"
                    log_info "Starship initialized in $home/.bashrc."
                fi
            fi
        done

    # Ensure the root user also has the configuration if the script is run as root
    if [ "$HOME" = "/root" ]; then
        mkdir -p "$HOME/.config"
        cp /etc/skel/.config/starship.toml "$HOME/.config/starship.toml"
        if ! grep -q 'starship init bash' "$HOME/.bashrc"; then
            echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
        fi
        source "$HOME/.bashrc"
    fi
}

# Function to install Rclone
install_rclone() {
    log_info "Checking Rclone installation..."
    if ! command -v rclone >/dev/null 2>&1; then
        log_info "Installing Rclone..."
        if curl -fsSL https://rclone.org/install.sh | bash; then
            log_info "Rclone installed successfully."
        else
            log_error "Failed to install Rclone."
        fi
    else
        log_info "Rclone is already installed."
    fi
}

# Function to configure SSH login alerts
setup_ssh_alerts() {
    log_info "Setting up SSH login alerts..."
    local repo_url="https://github.com/yashodhank/ssh-login-alert-telegram"
    local config_path="/opt/ssh-login-alert-telegram"

    # Clone the repository if it doesn't already exist
 if [ ! -d "$config_path" ]; then
        log_info "Cloning the SSH login alert repository..."
        if git clone "$repo_url" "$config_path" >/dev/null 2>&1; then
            log_info "Repository cloned successfully."
        else
            log_error "Failed to clone the repository."
            return 1
        fi
    fi

    # Set up or update credentials in the configuration
    get_credentials
    local creds="$config_path/credentials.config"
    log_info "Updating credentials configuration..."
    if [ -f "$creds" ]; then
        # Update the existing configuration
        sed -i "s|USERID=.*|USERID=($USERID)|" "$creds"
        sed -i "s|KEY=.*|KEY=\"$KEY\"|" "$creds"
    else
        # Create new configuration file
        echo "# Your USERID or Channel ID to display alert and key, we recommend you create new bot with @BotFather on Telegram" > "$creds"
        echo "USERID=($USERID)" >> "$creds"
        echo "KEY=\"$KEY\"" >> "$creds"
    fi

    if bash "$config_path/deploy.sh"; then
    log_info "SSH login alerts deployed successfully."
    else
        log_error "Failed to deploy SSH login alerts."
        return 1
    fi
}

# Function to install Neofetch and update MOTD
install_neofetch_update_motd() {
    export DEBIAN_FRONTEND=noninteractive
    rm -f /etc/motd # Clean up
    log_info "Installing Neofetch and updating MOTD..."
    if ! command -v neofetch >/dev/null 2>&1; then
        if apt-get install -y neofetch -qq >/dev/null 2>&1; then
            log_info "Neofetch installed successfully."
        else
            log_error "Failed to install Neofetch."
            return 1
        fi
    else
        log_info "Neofetch is already installed."
    fi

    if [ ! -f "/etc/profile.d/motd.sh" ]; then
        echo "neofetch" > "/etc/profile.d/motd.sh"
        chmod +x "/etc/profile.d/motd.sh"
        log_info "MOTD updated to run Neofetch."
    else
        log_info "MOTD already set to run Neofetch."
    fi
}

# Function to add SSH keys to all users with SSH access
add_ssh_keys_to_users() {
    log_info "Adding SSH keys to all users with SSH access..."
    local key_url="$SSH_KEYS_URL" # Default URL or user-provided
    local key_data=$(curl -fsSL "$key_url")
    if [ -z "$key_data" ]; then
        log_error "Failed to fetch SSH keys from $key_url."
        return 1
    fi

    # Iterate over all user directories in /home and root
    for user_dir in /root /home/*; do
        if [ -d "$user_dir" ] && [ -d "$user_dir/.ssh" ]; then
            local username=$(basename "$user_dir")
            log_info "Adding SSH keys to user: $username"
            echo "$key_data" >> "$user_dir/.ssh/authorized_keys"
            chown "$(id -u "$username"):$(id -g "$username")" "$user_dir/.ssh/authorized_keys"
            chmod 600 "$user_dir/.ssh/authorized_keys"
        fi
    done
}

# Main function to orchestrate the setup
main() {
    log_info "Initiating main setup functions."
    get_credentials "$1" "$2" "$3" # Pass CLI arguments for USERID, KEY, and SSH_KEYS_URL
    set_timezone
    update_system
    install_fonts
    setup_starship
    install_rclone
    install_docker
    setup_ssh_alerts "$@"
    install_neofetch_update_motd
    add_ssh_keys_to_users
    log_info "Setup completed successfully."
}

main "$@"
