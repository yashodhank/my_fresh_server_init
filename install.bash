#!/bin/bash

# Ensures the script is run as root and logs output
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

log_file="/var/log/setup_server.log"
exec > >(tee -a "$log_file") 2>&1

# Function to get USERID and KEY from environment variables or user input
get_credentials() {
    USERID="${1:-$USERID}"
    KEY="${2:-$KEY}"

    if [ -z "$USERID" ]; then
        read -p "Enter USERID: " USERID
    fi
    if [ -z "$KEY" ]; then
        read -p "Enter KEY: " KEY
    fi
}

# Function to update system and install required packages
update_system() {
    echo "Updating system and installing required packages..."
    apt-get update && apt-get -y upgrade
    for pkg in git sudo curl; do
        dpkg -s "$pkg" &>/dev/null || {
            echo "Installing $pkg..."
            apt-get install -y "$pkg"
        }
    done
}

# Function to install fonts
install_fonts() {
    echo "Installing fonts..."
    local fonts=("Hack/Regular/HackNerdFont-Regular.ttf"
                 "CodeNewRoman/Music/Regular/CodeNewRomanNerdFont-Regular.otf"
                 "RobotoMono/Regular/RobotoMonoNerdFont-Regular.ttf"
                 "Ubuntu/Regular/UbuntuNerdFont-Regular.ttf")
    mkdir -p /usr/local/share/fonts
    for font in "${fonts[@]}"; do
        local filename="/usr/local/share/fonts/${font##*/}"
        if [ ! -f "$filename" ]; then
            echo "Downloading $font..."
            curl -fL "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/$font" -o "$filename"
        else
            echo "$filename already installed."
        fi
    done
}

# Function to install and configure Starship prompt for all current and future users
setup_starship() {
    echo "Setting up Starship for all current and future users..."
    command -v starship >/dev/null 2>&1 || {
        echo "Installing Starship..."
        curl -sS https://starship.rs/install.sh | bash
    }
    mkdir -p /etc/skel/.config
    local config_url="https://gist.githubusercontent.com/yashodhank/0343daac9c8950bc63ffb9263043e345/raw/05de79957573bded1409f6236f41eb6b97384bf2/starship.toml"
    curl "$config_url" > /etc/skel/.config/starship.toml
    if ! grep -q 'starship init bash' /etc/profile.d/starship.sh 2>/dev/null; then
        echo 'eval "$(starship init bash)"' > /etc/profile.d/starship.sh
        chmod +x /etc/profile.d/starship.sh
    fi
}

# Function to install Rclone
install_rclone() {
    echo "Installing Rclone..."
    command -v rclone >/dev/null 2>&1 || {
        echo "Installing Rclone..."
        curl https://rclone.org/install.sh | bash
    }
}

# Function to configure SSH login alerts
setup_ssh_alerts() {
    echo "Setting up SSH login alerts..."
    local repo_url="https://github.com/yashodhank/ssh-login-alert-telegram"
    local config_path="/opt/ssh-login-alert-telegram"
    if [ ! -d "$config_path" ]; then
        git clone "$repo_url" "$config_path"
    fi
    local creds="$config_path/credentials.config"
    if [ ! -f "$creds" ]; then
        get_credentials "$@"
        echo -e "USERID=( $USERID ) \nKEY=\"$KEY\" \n" > "$creds"
        bash "$config_path/deploy.sh"
    else
        echo "SSH login alerts already configured."
    fi
}

# Additional function to install Neofetch and update MOTD
install_neofetch_update_motd() {
    echo "Installing Neofetch and updating MOTD..."
    if ! command -v neofetech >/dev/null 2>&1; then
        apt-get -y -qq install neofetch
    fi
    if [ ! -f "/etc/profile.d/motd.sh" ]; then
        echo "neofetch" > /etc/profile.d/motd.sh
        chmod +x /etc/profile.d/motd.sh
    else
        echo "MOTD already set to run Neofetch."
    fi
}

# Main function to orchestrate the setup
main() {
    update_system
    install_fonts
    setup_starship
    install_rclone
    setup_ssh_alerts "$@"
    install_neofetch_update_motd
    echo "Setup completed successfully."
}

main "$@"