# Server Setup Script

This script automates the process of setting up a server with the necessary software, configurations, and security enhancements. It's designed to ensure all required packages are installed, fonts are set up, the Starship prompt is configured for all users, and more, on Debian or Ubuntu systems.

## Prerequisites

- The script must be run as root.
- Your system should be based on Debian or Ubuntu, as the installation commands utilize `apt-get`.

## Getting Started

You can directly download and run the script from the GitHub repository using the following one-liner command:

```bash
curl -sS https://raw.githubusercontent.com/yashodhank/my_fresh_server_init/main/setup_server.sh | sudo bash -s -- -1001566247622 "your_key_here"
```

### Setup Instructions

1. **Clone the repository**:
   Clone the GitHub repository to your local system to examine or modify the script before execution:

   ```bash
   git clone https://github.com/yashodhank/my_fresh_server_init.git
   cd my_fresh_server_init
   ```

2. **Make the script executable**:
   Before running the script, make sure it is executable:

   ```bash
   chmod +x setup_server.sh
   ```

## Usage Options

The script supports several methods for providing the necessary USERID and KEY for SSH login alerts:

### Using Environment Variables

Set the USERID and KEY as environment variables before running the script:

```bash
export USERID=-1001566247622
export KEY="your_key_here"
sudo ./setup_server.sh
```

### Using Command-Line Arguments

Pass the USERID and KEY directly as command-line arguments:

```bash
sudo ./setup_server.sh -1001566247622 "your_key_here"
```

### Interactive Prompts

If USERID and KEY are not provided through environment variables or command-line arguments, the script will prompt you interactively:

```bash
sudo ./ReadME.md
# Follow the prompts to enter USERID and KEY
```

## Features

- **System Update**: Updates all packages to their latest versions.
- **Fonts**: Installs a curated selection of Nerd Fonts essential for developers and designers.
- **Starship Prompt**: Configures the Starship prompt for an enhanced terminal experience for all users.
- **Rclone**: Installs Rclone to manage and synchronize files across cloud storage services.
- **SSH Login Alerts**: Configures Telegram-based alerts for SSH logins.
- **Neofetch MOTD**: Sets up Neofetch to display system information at each login.

## Contributions

Contributions are welcome! For substantial changes, please open an issue first to discuss what you would like to change. Ensure you update tests as appropriate.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE) file for details.

### Enhanced Features:
- **Direct Usage Command**: Added a one-liner command for direct script execution, ideal for users who prefer quick setups without manual downloads.
- **Detailed Instructions**: Clarified steps for cloning and preparing the script to run, ensuring users understand each stage of the setup process.
- **Comprehensive Usage Options**: Expanded on ways to provide credentials to the script, ensuring flexibility for different user preferences and security concerns.

This README is designed to be comprehensive yet straightforward, guiding users through using the script effectively while offering multiple options to suit their setup preferences.
