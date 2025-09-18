#!/bin/bash

# Exit the script if any command fails
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to show usage
show_usage() {
    echo "Usage: $0 --path PROJECT_PATH --hostname HOSTNAME --domain-suffix SUFFIX [--webmin true|false] [--ip IP_ADDRESS]"
    echo "Required arguments:"
    echo "   --path PROJECT_PATH         Base installation directory (e.g., /opt/homeserver)."
    echo "   --hostname HOSTNAME         Hostname (e.g., homeserver)."
    echo "   --domain-suffix SUFFIX      Domain suffix (e.g., lan)."
    echo ""
    echo "Optional arguments:"
    echo "   --webmin [true|false]       Enable Webmin (default: true)."
    echo "   --ip IP_ADDRESS             IP address of the host machine (will be detected if not provided)."
    echo "   --help, -h                  Show this help."
    exit 1
}

# Default settings (for fallback only, will be overwritten by install.sh)
DEFAULT_PROJECT_DIR="/opt/homeserver"
DEFAULT_HOSTNAME=$(hostname | cut -d'.' -f1)
if [[ -z "$DEFAULT_HOSTNAME" || "$DEFAULT_HOSTNAME" == "localhost" ]]; then
    DEFAULT_HOSTNAME="homeserver"
fi
DEFAULT_DOMAIN_SUFFIX="lan"
ENABLE_WEBMIN=true
CERT_DAYS=3650

# Function to parse arguments
parse_arguments() {
    PROJECT_DIR="$DEFAULT_PROJECT_DIR"
    SERVER_HOSTNAME="$DEFAULT_HOSTNAME"
    DOMAIN_SUFFIX="$DEFAULT_DOMAIN_SUFFIX"
    ENABLE_WEBMIN=true
    SERVER_IP="" # Will be detected or filled by parameter

    while [[ $# -gt 0 ]]; do
        case $1 in
            --path)
                PROJECT_DIR="$2"
                shift 2
                ;;
            --hostname)
                SERVER_HOSTNAME="$2"
                shift 2
                ;;
            --domain-suffix)
                DOMAIN_SUFFIX="$2"
                shift 2
                ;;
            --webmin)
                if [[ "$2" == "true" ]]; then
                    ENABLE_WEBMIN=true
                elif [[ "$2" == "false" ]]; then
                    ENABLE_WEBMIN=false
                fi
                shift 2
                ;;
            --ip)
                SERVER_IP="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                ;;
            *)
                log_error "Unknown argument: $1"
                show_usage
                ;;
        esac
    done

    # Detect the IP if it wasn't provided via --ip
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
        if [[ -z "$SERVER_IP" ]]; then
            log_warn "Could not automatically detect the host IP. Using 127.0.0.1 as a fallback."
            SERVER_IP="127.0.0.1" # Fallback to avoid error
        fi
    fi

    NGINX_SSL_DIR="$PROJECT_DIR/nginx/ssl"
    NGINX_CONF_FILE="$PROJECT_DIR/nginx/reverse-proxy.conf"

    log_info "Configuration for Certificate Generation:"
    echo -e "   - Hostname: ${BLUE}$SERVER_HOSTNAME${NC}"
    echo -e "   - Domain: ${BLUE}$DOMAIN_SUFFIX${NC}"
    echo -e "   - Webmin: ${BLUE}$ENABLE_WEBMIN${NC}"
    echo -e "   - Server IP: ${BLUE}$SERVER_IP${NC}"
    echo -e "   - Project Directory: ${BLUE}$PROJECT_DIR${NC}"
    echo -e "   - Nginx SSL Directory: ${BLUE}$NGINX_SSL_DIR${NC}"
    echo -e "   - Nginx Configuration File: ${BLUE}$NGINX_CONF_FILE${NC}"
}

# Function to extract subdomains from nginx
extract_subdomains() {
    log_info "🔍 Attempting to parse nginx configuration at $NGINX_CONF_FILE for subdomains..."
    
    local found_subdomains=""

    if [[ ! -f "$NGINX_CONF_FILE" ]]; then
        log_warn "Nginx configuration file NOT FOUND at $NGINX_CONF_FILE. Subdomains will be based on defaults only."
        SUBDOMAINS="" # Ensure it's empty
        return # Exit the function, it's not a fatal error
    fi
    
    log_info "Content of 'server_name' found (for debugging):"
    grep -oP 'server_name\s+\K[^;]+' "$NGINX_CONF_FILE" | tr ' ' '\n' | sed 's/^/   /g'
    
    # Extract all server_name and process them
    found_subdomains=$(grep -oP 'server_name\s+\K[^;]+' "$NGINX_CONF_FILE" | \
                       tr ' ' '\n' | \
                       grep -v "^$" | \
                       grep -v "^\s*$" | \
                       sort | uniq)

    log_info "Raw 'server_name' values after grep/sort/uniq:"
    echo "$found_subdomains" | sed 's/^/   /g'

    local processed_subdomains=""
    for name in $found_subdomains; do
        # Remove the base hostname and domain suffix to isolate only the subdomain
        # Ex: "pihole.homeserver.lan" -> "pihole"
        # Ex: "ha.homeserver" -> "ha"
        local sub=$(echo "$name" | sed "s/\.${SERVER_HOSTNAME}\.${DOMAIN_SUFFIX}//" | sed "s/\.${SERVER_HOSTNAME}//")

        # If the original name contained the hostname, and the result is not empty or the hostname itself
        if [[ "$name" =~ "${SERVER_HOSTNAME}" && -n "$sub" && "$sub" != "$SERVER_HOSTNAME" ]]; then
            # Add only if it's a valid subdomain and not "localhost"
            if [[ "$sub" != "localhost" && "$sub" != "$SERVER_HOSTNAME" && "$sub" != "${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}" ]]; then
                processed_subdomains+="$sub "
            fi
        fi
    done
    
    # Filter "webmin" if it's disabled
    local final_subdomains=""
    for sub in $processed_subdomains; do
        if [[ "$sub" == "webmin" && "$ENABLE_WEBMIN" == "false" ]]; then
            log_warn "⚠️  Webmin disabled - ignoring 'webmin' extracted from configuration."
            continue
        fi
        final_subdomains+="$sub "
    done

    SUBDOMAINS=$(echo "$final_subdomains" | xargs) # Clean up extra spaces

    if [[ -z "$SUBDOMAINS" ]]; then
        log_warn "No additional subdomains detected in the nginx configuration (besides defaults)."
    else
        log_info "✅ Subdomains detected and processed from configuration:"
        for sub in $SUBDOMAINS; do
            echo -e "   - ${BLUE}$sub${NC}"
        done
    fi
}

# Main function
main() {
    parse_arguments "$@"
    
    log_info "🔐 Starting generation of a SINGLE self-signed certificate..."
    log_info "📅 Validity: $((CERT_DAYS/365)) years"
    echo ""

    # Automatically extract subdomains - MUST BE RUN FIRST TO UPDATE $SUBDOMAINS
    extract_subdomains

    # Create Subject Alternative Names (SAN) list
    # Includes the base hostname WITH and WITHOUT the .lan suffix, localhost, and the IP
    declare -a SAN_ARRAY # Use array to avoid string concatenation issues
    SAN_ARRAY+=("DNS:$SERVER_HOSTNAME") # homeserver
    SAN_ARRAY+=("DNS:$SERVER_HOSTNAME.$DOMAIN_SUFFIX") # homeserver.lan
    SAN_ARRAY+=("DNS:localhost")
    SAN_ARRAY+=("IP:$SERVER_IP")

    # Add COMMON subdomains by default (ensures they are always there)
    SAN_ARRAY+=("DNS:pihole.$SERVER_HOSTNAME")
    SAN_ARRAY+=("DNS:pihole.$SERVER_HOSTNAME.$DOMAIN_SUFFIX")
    SAN_ARRAY+=("DNS:ha.$SERVER_HOSTNAME")
    SAN_ARRAY+=("DNS:ha.$SERVER_HOSTNAME.$DOMAIN_SUFFIX")
    SAN_ARRAY+=("DNS:komodo.$SERVER_HOSTNAME")
    SAN_ARRAY+=("DNS:komodo.$SERVER_HOSTNAME.$DOMAIN_SUFFIX")

    if [[ "$ENABLE_WEBMIN" == "true" ]]; then
        SAN_ARRAY+=("DNS:webmin.$SERVER_HOSTNAME")
        SAN_ARRAY+=("DNS:webmin.$SERVER_HOSTNAME.$DOMAIN_SUFFIX")
    fi

    # Add EXTRA subdomains detected from nginx.conf (if any)
    for sub in $SUBDOMAINS; do
        if [[ ! -z "$sub" ]]; then
            SAN_ARRAY+=("DNS:${sub}.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}")
            SAN_ARRAY+=("DNS:${sub}.${SERVER_HOSTNAME}")
        fi
    done

    # Remove duplicates from the SAN_ARRAY (can happen with the mix of defaults and extraction)
    local unique_sans=""
    for san_entry in "${SAN_ARRAY[@]}"; do
        if ! grep -q -w "$san_entry" <<< "$unique_sans"; then
            unique_sans+="$san_entry "
        fi
    done
    SAN_ARRAY=($(echo "$unique_sans" | xargs)) # Assign back to the array

    # Format for the final OpenSSL string
    SAN_LIST=$(IFS=,; echo "${SAN_ARRAY[*]}")
    
    log_info "📋 Configured Subject Alternative Names (final for OpenSSL):"
    echo "$SAN_LIST" | tr ',' '\n' | sed 's/^ *//' | sed 's/^/   /'

    # Create temporary certificate directory to work in
    TEMP_CERT_DIR=$(mktemp -d)
    log_info "📂 Temporary working directory created: $TEMP_CERT_DIR"
    cd "$TEMP_CERT_DIR"

    # --- Generate PRIVATE KEY and SINGLE SELF-SIGNED CERTIFICATE ---
    log_info "📋 Generating server private key (homeserver.key)..."
    openssl genrsa -out homeserver.key 2048

    log_info "📋 Generating self-signed certificate (homeserver.crt) with all SANs..."

    # Create configuration file for SAN
    cat > openssl.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}
O = Home Server
C = BR

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = $SAN_LIST
EOF

    # Generate self-signed certificate directly with the key and config
    openssl req -x509 -new -nodes -key homeserver.key -sha256 -days $CERT_DAYS -out homeserver.crt \
      -subj "/CN=${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}/O=Home Server/C=BR" \
      -config openssl.cnf -extensions v3_req

    # --- Copy homeserver.crt to ca.crt (for import into clients) ---
    log_info "Copying homeserver.crt to ca.crt (for import on clients)..."
    cp homeserver.crt ca.crt

    # 3. Clean up temporary files from the working directory
    log_info "Cleaning up intermediate files..."
    rm openssl.cnf

    # 4. Set permissions on temporary files
    chmod 600 homeserver.key
    chmod 644 homeserver.crt ca.crt # ca.crt is now homeserver.crt

    # 5. Create the final Nginx SSL directory
    log_info "📂 Creating final Nginx SSL directory at: $NGINX_SSL_DIR"
    mkdir -p "$NGINX_SSL_DIR"
    chmod 700 "$NGINX_SSL_DIR" 

    # 6. Copy certificates to Nginx
    log_info "📤 Moving certificates to the final SSL directory..."
    cp homeserver.crt homeserver.key "$NGINX_SSL_DIR/"
    cp ca.crt "$NGINX_SSL_DIR/"

    # 7. Adjust permissions of the copied files (now in the final directory)
    chmod 644 "$NGINX_SSL_DIR/homeserver.crt"
    chmod 600 "$NGINX_SSL_DIR/homeserver.key"
    chmod 644 "$NGINX_SSL_DIR/ca.crt"

    # 8. Clean up the temporary working directory
    cd - > /dev/null # Go back to the previous directory
    rm -r "$TEMP_CERT_DIR"
    log_info "🗑️ Temporary working directory removed: $TEMP_CERT_DIR"

    # 9. Verify generated certificate
    log_info "🔍 Verifying generated certificate ($NGINX_SSL_DIR/homeserver.crt)..."
    echo -e "${GREEN}✅ Domains included in the certificate:${NC}"
    openssl x509 -in "$NGINX_SSL_DIR/homeserver.crt" -noout -text | grep -A1 "Subject Alternative Name" | \
        tail -1 | tr ',' '\n' | sed 's/^ *//' | sed 's/^/   /'

    # 10. Check expiration dates
    EXPIRY_DATE=$(openssl x509 -in "$NGINX_SSL_DIR/homeserver.crt" -noout -enddate | cut -d= -f2)

    echo ""
    echo -e "${GREEN}✅ Certificates generated and moved successfully!${NC}"
    echo ""
    echo "📅 Certificate expiration date: ${BLUE}$EXPIRY_DATE${NC}"
    echo ""
    echo -e "${GREEN}📁 Final certificates available at: ${BLUE}$NGINX_SSL_DIR/${NC}"
    echo -e "${GREEN}⭐ The file '${BLUE}ca.crt${NC}' is a copy of '${BLUE}homeserver.crt${NC}' and should be imported into your client devices.${NC}"
}

main "$@"
