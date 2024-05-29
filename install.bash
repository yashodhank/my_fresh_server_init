#!/bin/bash

# Ensure the script is run as root and set up logging
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

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

log_info "Script execution started."

# Function to get USERID and KEY from environment variables or user input
get_credentials() {
    USERID="${1:-$USERID}"
    KEY="${2:-$KEY}"

    if [ -z "$USERID" ]; then
        read -p "Enter USERID: " USERID
        log_info "USERID provided by user input."
    fi
    if [ -z "$KEY" ]; then
        read -p "Enter KEY: " KEY
        log_info "KEY provided by user input."
    fi
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

    # Get the current system timezone
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
}

# Function to update system and install required packages
update_system() {
    log_info "Updating system and installing required packages..."
    if apt-get update -qq; then
        log_info "System update completed."
    else
        log_error "Failed to update package lists."
        return 1
    fi

    if apt-get -y upgrade -qq; then
        log_info "System upgrade completed."
    else
        log_error "Failed to upgrade system."
        return 1
    fi

    for pkg in git sudo curl wget nano htop tmux screen git unzip zip rsync tree net-tools ufw jq ncdu nmap telnet mtr iputils-ping tcpdump traceroute bind9-dnsutils whois sysstat iotop iftop vnstat glances snapd software-properties-common sshguard rkhunter mc lsof strace dstat iperf3 ntp build-essential python3-pip; do
        if dpkg -s "$pkg" &>/dev/null; then
            log_info "$pkg is already installed."
        else
            log_info "Installing $pkg..."
            if apt-get install -y "$pkg" -qq; then
                log_info "$pkg installed successfully."
            else
                log_error "Failed to install $pkg."
            fi
        fi
    done
}

# Function to install Docker
install_docker() {
    log_info "Checking Docker installation..."
    if ! command -v docker >/dev/null 2>&1; then
        log_info "Installing Docker..."
        if apt-get update -qq && \
           apt-get install -y apt-transport-https ca-certificates curl software-properties-common -qq && \
           curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
           add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
           apt-get update -qq && \
           apt-get install -y docker-ce docker-ce-cli containerd.io -qq; then
            log_info "Docker installed successfully."
        else
            log_error "Failed to install Docker."
            return 1
        fi
    else
        log_info "Docker is already installed."
    fi
}

# Function to install NERD Fonts
install_fonts() {
    log_info "Installing NERD Fonts..."
    local fonts=("Hack/Regular/HackNerdFont-Regular.ttf"
                 "CodeNewRoman/Music/Regular/CodeNewRomanNerdFont-Regular.otf"
                 "RobotoMono/Regular/RobotoMonoNerdFont-Regular.ttf"
                 "Ubuntu/Regular/UbuntuNerdFont-Regular.ttf")
    mkdir -p /usr/local/share/fonts
    for font in "${fonts[@]}"; do
        local filename="/usr/local/share/fonts/${font##*/}"
        if [ ! -f "$filename" ]; then
            log_info "Downloading $font..."
            curl -fL "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/$font" -o "$filename"
        else
            log_info "$filename is already installed."
        fi
    done
}

# Function to install and configure Starship prompt for all current and future users
setup_starship() {
    log_info "Setting up Starship for all current and future users..."
    
    # Install Starship if it's not already installed
    if ! command -v starship >/dev/null 2>&1; then
        log_info "Installing Starship..."
        if curl -sS https://starship.rs/install.sh | sh -s -- -y; then
            log_info "Starship installed successfully."
        else
            log_error "Failed to install Starship."
            return 1
        fi
    fi

    local config_url="https://gist.githubusercontent.com/yashodhank/0343daac9c8950bc63ffb9263043e345/raw/starship.toml"
    mkdir -p /etc/skel/.config
    if curl -sS "$config_url" -o /etc/skel/.config/starship.toml; then
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
        if curl https://rclone.org/install.sh | bash; then
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
        if git clone "$repo_url" "$config_path"; then
            log_info "Repository cloned successfully."
        else
            log_error "Failed to clone the repository."
            return 1
        fi
    fi

    get_credentials "$@"
    
    local creds="$config_path/credentials.config"
    log_info "Updating credentials configuration..."
    if [ -f "$creds" ]; then
        # Using different delimiters for sed to avoid issues with characters like '/' and special handling for '(' and ')'
        sed -i "s|USERID=(.*|USERID=($USERID)|" "$creds"
        sed -i "s|KEY=\".*|KEY=\"$KEY\"|" "$creds"
    else
        # If credentials.config doesn't exist, create it with the new values
        echo "# Your USERID or Channel ID to display alert and key, we recommend you create new bot with @BotFather on Telegram" > "$creds"
        echo "USERID=($USERID)" >> "$creds"
        echo "KEY=\"$KEY\"" >> "$creds"
    fi

    if bash "$config_path/deploy.sh"; then
        log_info "SSH login alerts deployed successfully."
    else
        log_error "Failed to deploy SSH login alerts."
    fi
}

# Function to install Neofetch and update MOTD
install_neofetch_update_motd() {
    log_info "Installing Neofetch and updating MOTD..."
    if ! command -v neofetch >/dev/null 2>&1; then
        if apt-get -y -qq install neofetch; then
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

# Main function to orchestrate the setup
main() {
    log_info "Initiating main setup functions."
    update_system
    install_fonts
    setup_starship
    install_rclone
    setup_ssh_alerts "$@"
    install_neofetch_update_motd
    log_info "Setup completed successfully."
}

main "$@"
