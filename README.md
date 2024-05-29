# My Fresh Server Initializr

This script automates the setup of a new server, handling everything from system updates and font installations to configuring useful utilities like Starship, Rclone, and Neofetch. It is designed to be run with root privileges and logs all operations to ensure transparency and traceability.

## Prerequisites
- The script must be executed with root privileges.
- A Debian-based Linux distribution (such as Ubuntu).

## Features
- **System Update**: Ensures all packages are up-to-date.
- **Font Installation**: Installs a set of Nerd Fonts useful for developers and designers.
- **Starship Setup**: Configures the Starship shell prompt for an enhanced terminal experience.
- **Docker Installation**: Installs Docker for container management.
- **Rclone Setup**: Installs Rclone for managing cloud storage services.
- **SSH Alert Setup**: Configures alerts for SSH logins using Telegram.
- **Neofetch Installation**: Installs Neofetch and sets it up to display system information at login.

## Installation

To run the script directly from GitHub, use the following command:

```bash
curl -sS https://raw.githubusercontent.com/yashodhank/my_fresh_server_init/main/install.bash | sudo bash -s -- CHANNELID "YOUR_TELEGRAM_BOT_KEY"
```
> #### Example:
> curl -sS https://raw.githubusercontent.com/yashodhank/my_fresh_server_init/main/install.bash | sudo bash -s -- -1001566247622 "738435042:AAHcvVtMTeRAQbuCEFRq9wiIkbYcPYCtcjo"
>
>  _Note: If you want to make sure the script is aware of the variables, and considering security best practices, you might consider downloading the script, reviewing its contents, setting the environment variables, and running it locally, rather than piping it directly from `curl`._


### Environment Variables and Inputs

1. **USERID and KEY**: These are used for setting up SSH login alerts. They can be provided as:
   - Environment variables: `USERID` and `KEY`
   - Command-line arguments: Passed directly to the script.

2. **TIMEZONE**: Set the server's timezone. If not provided, the script will prompt for it or default to 'Asia/Kolkata'.

## Usage

### Setting Timezone

The script allows setting the system timezone via an environment variable or by prompting the user. To run the script with a specific timezone:

```bash
export TIMEZONE="America/New_York"
curl -sS https://raw.githubusercontent.com/yashodhank/my_fresh_server_init/main/install.bash | sudo bash -s -- CHANNELID "YOUR_TELEGRAM_BOT_KEY"
```

If no timezone is specified, it will default to 'Asia/Kolkata'.

### Providing USERID/CHANNELID and KEY for SSH Alerts

You can export these before running the script:

```bash
export USERID="CHANNELID"
export KEY="YOUR_TELEGRAM_BOT_KEY"
curl -sS https://raw.githubusercontent.com/yashodhank/my_fresh_server_init/main/install.bash | sudo bash -s -- CHANNELID "YOUR_TELEGRAM_BOT_KEY"
```

Alternatively, you can pass them directly as arguments:

```bash
sudo ./install.bash CHANNELID "YOUR_TELEGRAM_BOT_KEY"
```

If not provided, the script will prompt for these values during execution.


#### Example:
```bash
export TIMEZONE="America/New_York"
export USERID="-1001566247622"
export KEY="738435042:AAHcvVtMTeRAQbuCEFRq9wiIkbYcPYCtcjo"
curl -sS https://raw.githubusercontent.com/yashodhank/my_fresh_server_init/main/install.bash | sudo bash
```

## Detailed Step-by-Step Functions

- **update_system()**: Updates the package lists and upgrades all the installed packages.
- **install_fonts()**: Checks if specified fonts are installed, downloads, and installs them if not.
- **setup_starship()**: Installs the Starship prompt and configures it for all users.
- **install_docker()**: Installs Docker using the official Docker repositories.
- **install_rclone()**: Downloads and installs Rclone.
- **setup_ssh_alerts()**: Configures Telegram alerts for SSH login attempts using provided `USERID` and `KEY`.
- **install_neofetch_update_motd()**: Installs Neofetch and configures it to display system info on login.

## Logging

All output from the script is logged to `/var/log/setup_server.log`, ensuring that you can review what changes were made and troubleshoot any issues.

## Contributing

Contributions to this script are welcome. Please fork the repository and submit pull requests with any enhancements.

## License

This script is released under the MIT License. For more details, see the `LICENSE` file in the repository.


### Notes

- Replace `YOUR_TELEGRAM_BOT_KEY` with the actual key from Telegram.
- Modify any URLs or commands according to your repository or environment setup.
- Ensure that all environment variables and paths are correct and tested in your environment.

This README provides a comprehensive guide on how to use and understand the script, including detailed instructions for setup and customization options.
