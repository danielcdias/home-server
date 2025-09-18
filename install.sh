#!/bin/bash

# Exit the script if any command fails
set -e

# --- CAPTURE ORIGINAL USER AND GROUP BEFORE ANYTHING ELSE ---
# The user who executes the script (even with sudo, USER still reflects the original user)
ORIGINAL_USER="${SUDO_USER:-$(whoami)}"
# The primary group of the original user
ORIGINAL_GROUP=$(id -gn "$ORIGINAL_USER")
# --- END OF CAPTURE ---

# Default settings
DEFAULT_INSTALL_DIR="/opt/home-server"
DEFAULT_HOSTNAME=$(hostname | cut -d'.' -f1)
if [[ -z "$DEFAULT_HOSTNAME" || "$DEFAULT_HOSTNAME" == "localhost" ]]; then
    DEFAULT_HOSTNAME="homeserver"
fi
DEFAULT_DOMAIN_SUFFIX="lan"
SERVICE_NAME="homeserver"
# The script's directory (where the git clone is)
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "   --install-dir PATH            Final installation directory (default: $DEFAULT_INSTALL_DIR)"
    echo "   --hostname HOSTNAME           Hostname (default: $DEFAULT_HOSTNAME)"
    echo "   --domain-suffix SUFFIX        Domain suffix (default: $DEFAULT_DOMAIN_SUFFIX)"
    echo "   --non-interactive             Non-interactive mode (uses defaults or arguments)"
    echo "   --help, -h                    Show this help"
    exit 1
}

# Log functions (log_info, log_warn, log_error)
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Function for prompt with default value
prompt_with_default() {
    local message="$1"
    local default_value="$2"
    local variable_name="$3"
    echo -e "${BLUE}🤖 ${message}${NC}"
    read -p "$(echo -e "${BLUE}     (press ENTER for '${default_value}'): ${NC}")" user_input
    if [[ -z "$user_input" ]]; then
        eval "$variable_name=\"$default_value\""
        echo -e "${GREEN}     ✅ Using: ${default_value}${NC}"
    else
        eval "$variable_name=\"$user_input\""
        echo -e "${GREEN}     ✅ Using: ${user_input}${NC}"
    fi
    echo
}

# Function to confirm action
confirm_action() {
    local message="$1"
    echo -e "${YELLOW}⚠️  ${message}${NC}"
    read -p "$(echo -e "${YELLOW}     Are you sure you want to continue? (Y/n): ${NC}")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Operation cancelled.${NC}"
        exit 0
    fi
}

# Function to ask about Webmin
prompt_webmin() {
    echo -e "${BLUE}🤖 Webmin support${NC}"
    read -p "$(echo -e "${BLUE}     Do you want to enable Webmin support (requires installation if it doesn't exist)? (Y/n): ${NC}")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_WEBMIN=false
        echo -e "${YELLOW}     ⚠️  Webmin support disabled${NC}"
    else
        ENABLE_WEBMIN=true
        echo -e "${GREEN}     ✅ Webmin support enabled${NC}"
    fi
    echo
}

# Function to parse arguments
parse_arguments() {
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    SERVER_HOSTNAME="$DEFAULT_HOSTNAME"
    DOMAIN_SUFFIX="$DEFAULT_DOMAIN_SUFFIX"
    ENABLE_WEBMIN=true
    local non_interactive=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir) INSTALL_DIR="$2"; shift 2 ;;
            --hostname) SERVER_HOSTNAME="$2"; shift 2 ;;
            --domain-suffix) DOMAIN_SUFFIX="$2"; shift 2 ;;
            --non-interactive) non_interactive=true; shift ;;
            --help|-h) show_usage ;;
            *) log_error "Unknown argument: $1"; show_usage ;;
        esac
    done
    
    if [[ "$non_interactive" == false ]]; then
        echo -e "${GREEN}==========================================${NC}"
        echo -e "${GREEN}      HOME SERVER INTERACTIVE SETUP       ${NC}"
        echo -e "${GREEN}==========================================${NC}\n"
        
        prompt_with_default "Enter the final installation directory" "$DEFAULT_INSTALL_DIR" "INSTALL_DIR"
        prompt_with_default "Enter the hostname (main domain)" "$DEFAULT_HOSTNAME" "SERVER_HOSTNAME"
        prompt_with_default "Enter the domain suffix (lan, local, etc.)" "$DEFAULT_DOMAIN_SUFFIX" "DOMAIN_SUFFIX"
        prompt_webmin
        
        echo -e "${GREEN}📋 Configuration summary:${NC}"
        echo -e "      📦 Installation directory: ${GREEN}$INSTALL_DIR${NC}"
        echo -e "      🌐 Hostname: ${GREEN}$SERVER_HOSTNAME${NC}"
        echo -e "      🔗 Full Domain: ${GREEN}$SERVER_HOSTNAME.$DOMAIN_SUFFIX${NC}"
        echo -e "      🖥️  Webmin: ${GREEN}$([[ "$ENABLE_WEBMIN" == true ]] && echo "Enabled" || echo "Disabled")${NC}\n"
        
        confirm_action "The project will be installed and configured in the destination directory."
    fi
    
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
}

# Function to check for root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root!"
    fi
}

# Function to check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    if ! command -v docker &> /dev/null; then log_error "Docker is not installed!"; fi
    if ! command -v docker-compose &> /dev/null && ! (command -v docker &> /dev/null && docker compose version &> /dev/null); then log_error "Docker Compose is not installed!"; fi
    if ! command -v openssl &> /dev/null; then log_error "OpenSSL is not installed!"; fi
    if ! command -v rsync &> /dev/null; then log_error "rsync is not installed! Please install with 'sudo apt-get install rsync' or 'sudo yum install rsync'."; fi
    log_info "Dependencies checked."
}

# Function to prepare the installation directory
prepare_install_dir() {
    log_info "Preparing installation directory: $INSTALL_DIR"
    if [ -d "$INSTALL_DIR" ]; then
        log_warn "The installation directory already exists."
        confirm_action "This may overwrite existing files. Do you want to continue?"
    fi
    mkdir -p "$INSTALL_DIR" || log_error "Failed to create installation directory: $INSTALL_DIR"
    
    log_info "Copying project files from $SOURCE_DIR to $INSTALL_DIR..."
    rsync -av --progress "$SOURCE_DIR/" "$INSTALL_DIR/" --exclude ".git" --exclude ".gitignore" || log_error "Failed to copy files with rsync! Installation aborted."
    
    # Create directories that may not exist in the source but are needed at runtime
    mkdir -p "$INSTALL_DIR/runtime_config/etc-pihole"
    mkdir -p "$INSTALL_DIR/runtime_config/home-assistant/config"
    log_info "Installation directory prepared successfully."
}

# Function to generate the .env configuration file
generate_config_env() {
    local config_file="$1/config.env"
    log_info "Generating environment configuration file at $config_file"
    
    cat > "$config_file" << EOF
# This file is automatically generated by install.sh
# Do not edit manually, as your changes will be lost on the next installation.

# Domain and Network Settings
SERVER_HOSTNAME=$SERVER_HOSTNAME
DOMAIN_SUFFIX=$DOMAIN_SUFFIX

# Component Settings
ENABLE_WEBMIN=$ENABLE_WEBMIN
EOF
    log_info "✅ config.env file generated."
}

# Function to process templates
process_templates() {
    log_info "Processing template files..."

    # Process index.html.tpl -> index.html
    local index_tpl="$INSTALL_DIR/nginx/html/index.html.tpl"
    local index_html="$INSTALL_DIR/nginx/html/index.html"
    if [[ -f "$index_tpl" ]]; then
        # Replace domain placeholders
        sed "s/{{SERVER_HOSTNAME}}/$SERVER_HOSTNAME/g; s/{{DOMAIN_SUFFIX}}/$DOMAIN_SUFFIX/g" "$index_tpl" > "$index_html"
        # Remove Webmin link if disabled
        if [[ "$ENABLE_WEBMIN" == false ]]; then
            sed -i '/webmin/d' "$index_html"
        fi
        log_info "✅ nginx/html/index.html.tpl template processed."
    fi

    # Process reverse-proxy.conf.tpl
    # The final processing will be done by envsubst in the container,
    # but we remove the Webmin block here if necessary.
    local nginx_tpl="$INSTALL_DIR/nginx/reverse-proxy.conf.tpl"
    if [[ "$ENABLE_WEBMIN" == false && -f "$nginx_tpl" ]]; then
        # Use awk to safely remove the Webmin block
        awk '/# Proxy for Webmin/,/}/ {next} 1' "$nginx_tpl" > "${nginx_tpl}.tmp" && mv "${nginx_tpl}.tmp" "$nginx_tpl"
        log_info "✅ Webmin block removed from nginx/reverse-proxy.conf.tpl."
    fi
}

# Function to create the service file
create_service_file() {
    log_info "Creating service file at: $SERVICE_FILE"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Home Server Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$SERVICE_FILE"
    log_info "Service file created."
}

# Function to configure and enable the service
setup_service() {
    log_info "Configuring systemd service..."
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    log_info "Service $SERVICE_NAME enabled for automatic startup."
}

# Function to generate certificates
generate_certificates() {
    local cert_script="$INSTALL_DIR/generate-certs.sh"
    if [[ ! -f "$cert_script" ]]; then
        log_error "generate-certs.sh script not found at $INSTALL_DIR";
    fi

    # Detect the main IP address of the host machine
    local host_ip
    host_ip=$(hostname -I | awk '{print $1}')
    if [[ -z "$host_ip" ]]; then
        log_warn "Could not detect host IP. The certificate will be generated without an IP."
    else
        log_info "Host IP detected for certificate: $host_ip"
    fi
    
    log_info "Generating SSL certificates..."
    chmod +x "$cert_script"
    # Pass all parameters, including the detected host IP
    "$cert_script" --path "$INSTALL_DIR" --hostname "$SERVER_HOSTNAME" --domain-suffix "$DOMAIN_SUFFIX" --webmin "$ENABLE_WEBMIN" --ip "$host_ip"
}

# Function: Create uninstall.info
create_uninstall_info() {
    log_info "Creating uninstallation information file at $INSTALL_DIR/uninstall.info..."
    echo "INSTALL_DIR=$INSTALL_DIR" > "$INSTALL_DIR/uninstall.info"
    echo "SYSTEMD_SERVICE_NAME=$SERVICE_NAME.service" >> "$INSTALL_DIR/uninstall.info"
    chmod 600 "$INSTALL_DIR/uninstall.info" # Restricted permissions
    log_info "✅ uninstall.info file created."
}

# Main function
main() {
    check_root
    parse_arguments "$@"
    check_dependencies
    
    prepare_install_dir
    generate_config_env "$INSTALL_DIR"
    process_templates

    # Check if the main .env exists and alert the user
    if [[ ! -f "$INSTALL_DIR/.env" ]]; then
        log_warn "Secrets .env file not found at $INSTALL_DIR."
        log_warn "Copy .env.example to .env and fill in the passwords before starting the service."
    fi
    
    # Optional: Install and configure Webmin here if necessary
    # if [[ "$ENABLE_WEBMIN" == true ]]; then ... fi

    create_service_file
    setup_service
    generate_certificates
    create_uninstall_info
    
    # --- NEW ACTION: Restore ownership ---
    log_info "Restoring ownership of the installation folder to ${BLUE}${ORIGINAL_USER}:${ORIGINAL_GROUP}${NC}..."
    chown -R "$ORIGINAL_USER:$ORIGINAL_GROUP" "$INSTALL_DIR" || log_warn "Failed to restore ownership. Check permissions manually at '$INSTALL_DIR'."
    log_info "✅ Ownership of the installation folder restored."
    # --- END OF NEW ACTION ---

    echo ""
    log_info "=== ✅ INSTALLATION COMPLETE ✅ ==="
    log_info "The execution files are in: $INSTALL_DIR"
    log_info "The environment configuration is in: $INSTALL_DIR/config.env"
    log_info "${YELLOW}Remember to configure the secrets in: $INSTALL_DIR/.env"
    log_info "${YELLOW}Also remember to create file config.json in folder $INSTALL_DIR/postgres/config"
    log_info "The systemd service '$SERVICE_NAME' has been created and enabled."
    log_info ""
    log_warn "Run 'sudo systemctl start $SERVICE_NAME' to start the services."
    log_info "Access the dashboard at: https://$SERVER_HOSTNAME"
    log_info ""
    log_info "${GREEN}To uninstall, navigate to '${INSTALL_DIR}' and run 'sudo ./uninstall.sh'.${NC}"
    log_info "Installation finished successfully! 🚀"
}

main "$@"
