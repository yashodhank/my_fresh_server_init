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

# Function to set system timezone
set_timezone() {
    echo "Setting system timezone..."
    if [ $(timedatectl show --value --property Timezone) != "Asia/Kolkata" ]; then
        timedatectl set-timezone Asia/Kolkata
        echo "Timezone set to Asia/Kolkata."
    else
        echo "Timezone already set to Asia/Kolkata."
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

# Function to install Docker
install_docker() {
    echo "Installing Docker..."
    if ! command -v docker >/dev/null 2>&1; then
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
    else
        echo "Docker already installed."
    fi
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
    
    # Install Starship if it's not already installed
    if ! command -v starship >/dev/null 2>&1; then
        echo "Installing Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y || {
            echo "Failed to install Starship." >&2
            return 1  # Return with error code if installation fails
        }
    fi

    # Download and apply the custom Starship configuration
    STARSHIP_CONFIG_URL="https://gist.githubusercontent.com/yashodhank/0343daac9c8950bc63ffb9263043e345/raw/starship.toml"
    mkdir -p /etc/skel/.config
    curl -sS "$STARSHIP_CONFIG_URL" -o /etc/skel/.config/starship.toml || {
        echo "Failed to download the Starship configuration." >&2
        return 1
    }

    # Apply the configuration to all existing users
    getent passwd | while IFS=: read -r name _ uid gid _ home shell; do
        if [ "$uid" -ge 1000 ] && [ -d "$home" ] && [[ "$shell" == *"/bash" ]]; then
            local config_dir="$home/.config"
            mkdir -p "$config_dir"
            cp /etc/skel/.config/starship.toml "$config_dir/starship.toml"

            # Make sure to source Starship in .bashrc
            if ! grep -q 'starship init bash' "$home/.bashrc"; then
                echo 'eval "$(starship init bash)"' >> "$home/.bashrc"
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
    
    # Clone the repository if it doesn't already exist
    if [ ! -d "$config_path" ]; then
        git clone "$repo_url" "$config_path"
    fi
    
    # Ensure credentials are fetched every time
    get_credentials "$@"
    
    local creds="$config_path/credentials.config"
    
    # Update or create the credentials.config with new values using robust sed pattern
    if [ -f "$creds" ]; then
        # Using alternate delimiter '|' to avoid issues with slashes and special characters
        sed -i "s|USERID=(.*|USERID=($USERID)|" "$creds"
        sed -i "s|KEY=\".*|KEY=\"$KEY\"|" "$creds"
    else
        # Create a new credentials.config file if it does not exist
        echo "# Your USERID or Channel ID to display alert and key, we recommend you create new bot with @BotFather on Telegram" > "$creds"
        echo "USERID=($USERID)" >> "$creds"
        echo "KEY=\"$KEY\"" >> "$creds"
    fi
    
    # Execute the deployment script
    bash "$config_path/deploy.sh"
    
    echo "SSH login alerts have been configured with the latest details."
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
