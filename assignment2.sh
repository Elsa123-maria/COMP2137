#!/bin/bash

set -e  # when a command fails exit immediately
set -u  # Treat unset variables as an error
set -o pipefail  #Ensure pipeline errors are detected properly

log_message() {
    echo "INFORMATION $1"
}

terminate_script() {
    echo "ERROR $1" >&2
    exit 1
}

log_message "Starting custom system setup script..."

# Ensure script is executed with root previlages
if [[ $EUID -ne 0 ]]; then
    terminate_script "This script must be executed as root. Use sudo."
fi

# Identify and configure network settings if Netplan is available
NETWORK_CONFIG_FILE=$(find /etc/netplan/ -type f -name "*.yaml" | head -n 1)
STATIC_IP="192.168.16.21/24"
if [[ -n "$NETWORK_CONFIG_FILE" ]]; then
    log_message "Configuring network settings in $NETWORK_CONFIG_FILE..."
    if grep -q "$STATIC_IP" "$NETWORK_CONFIG_FILE"; then
        log_message "Network settings already configured. Skipping..."
    else
        chmod 600 "$NETWORK_CONFIG_FILE"
        cat > "$NETWORK_CONFIG_FILE" <<EOL
network:
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - $STATIC_IP
      routes:
        - to: default
          via: 192.168.16.2
  version: 2
EOL
        chmod 644 "$NETWORK_CONFIG_FILE"
        netplan apply || terminate_script "Network configuration update failed."
        log_message "Network configuration applied successfully."
    fi
else
    log_message "No network configuration file found. Skipping network setup."
fi

# Modify /etc/hosts
HOSTS_FILE="/etc/hosts"
if ! grep -q "$STATIC_IP server1" "$HOSTS_FILE"; then
    log_message "Updating /etc/hosts file..."
    echo "$STATIC_IP server1" >> "$HOSTS_FILE"
else
    log_message "/etc/hosts is already updated."
fi

# Install required software if not already installed
log_message "Verifying necessary software packages..."
REQUIRED_PACKAGES=("apache2" "squid")
for PACKAGE in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "$PACKAGE"; then
        log_message "Installing $PACKAGE..."
        apt update -y && apt install -y "$PACKAGE" || terminate_script "Installation of $PACKAGE failed."
    else
        log_message "$PACKAGE is already installed. Skipping."
    fi
done

# Enable and start required services
log_message "Ensuring services are running..."
systemctl enable --now apache2 squid || terminate_script "Service startup failed."

# Define users for creation
USER_LIST=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

# Function to configure SSH for users
configure_ssh() {
    local USERNAME="$1"
    local HOME_DIR="/home/$USERNAME"
    local SSH_PATH="$HOME_DIR/.ssh"
    mkdir -p "$SSH_PATH"
    chown "$USERNAME:$USERNAME" "$SSH_PATH"
    chmod 700 "$SSH_PATH"
    
    [[ ! -f "$SSH_PATH/id_rsa.pub" ]] && sudo -u "$USERNAME" ssh-keygen -t rsa -b 4096 -N "" -f "$SSH_PATH/id_rsa"
    [[ ! -f "$SSH_PATH/id_ed25519.pub" ]] && sudo -u "$USERNAME" ssh-keygen -t ed25519 -N "" -f "$SSH_PATH/id_ed25519"
    
    cat "$SSH_PATH/id_rsa.pub" "$SSH_PATH/id_ed25519.pub" > "$SSH_PATH/authorized_keys"
    chown "$USERNAME:$USERNAME" "$SSH_PATH/authorized_keys"
    chmod 600 "$SSH_PATH/authorized_keys"
    log_message "SSH configuration complete for $USERNAME."
}

# Create user accounts and configure SSH access
for USERNAME in "${USER_LIST[@]}"; do
    if ! id "$USERNAME" &>/dev/null; then
        log_message "Creating user $USERNAME..."
        useradd -m -s /bin/bash "$USERNAME" || terminate_script "Failed to create user $USERNAME."
    else
        log_message "User $USERNAME already exists. Skipping."
    fi
    configure_ssh "$USERNAME"
done

# Assign sudo previlages to user dennis
if id "dennis" &>/dev/null; then
    log_message "Granting sudo access to dennis..."
    usermod -aG sudo dennis
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" >> "/home/dennis/.ssh/authorized_keys"
fi

log_message "System setup completed successfully."
