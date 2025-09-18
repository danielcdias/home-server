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
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- 1. ROOT PERMISSIONS CHECK ONLY ---
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_error "This script needs to be run as root. Use 'sudo ./uninstall.sh'."
    fi
}
# Call the root check immediately
check_root

# --- 2. DIRECTORY AND uninstall.info FILE CHECK ---
# The uninstaller MUST be run from the installation folder.
check_uninstall_dir() {
    local current_dir="$(pwd)"
    local uninstall_info_file="$current_dir/uninstall.info"

    if [[ ! -f "$uninstall_info_file" ]]; then
        log_error "The file '${BLUE}uninstall.info${NC}' was not found in this directory."
        log_error "This script MUST be run from the Home Server installation folder (where 'uninstall.info' is)."
        log_error "Please navigate to the installation folder (e.g., /opt/home-server) and run the script again: ${YELLOW}sudo ./uninstall.sh${NC}"
    fi

    # Load the variables from uninstall.info
    source "$uninstall_info_file"
    
    # Check if INSTALL_DIR was loaded and if it matches the current directory
    if [[ -z "$INSTALL_DIR" || "$INSTALL_DIR" != "$current_dir" ]]; then
        log_error "The current directory '${BLUE}$current_dir${NC}' does not match the INSTALL_DIR registered in 'uninstall.info' ('${BLUE}$INSTALL_DIR${NC}')."
        log_error "Please navigate to the correct installation folder and run the script again: ${YELLOW}sudo ./uninstall.sh${NC}"
    fi

    log_info "Confirmed: Running uninstaller from the installation folder: ${BLUE}$INSTALL_DIR${NC}"
}
# Call the directory check and load the variables immediately after the root check.
check_uninstall_dir


# Function to ask for confirmation (Y/N only)
confirm_action() {
    read -p "Are you sure you want to continue with the uninstallation? (Y/N): " -n 1 -r REPLY_CONFIRMATION
    echo # Add a new line after the single-character response
    if [[ ! "$REPLY_CONFIRMATION" =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by the user."
        exit 0
    fi
}

# Main uninstallation function
main() {
    log_info "==============================================="
    log_info "Starting Home Server uninstallation process"
    log_info "==============================================="

    # The INSTALL_DIR and SYSTEMD_SERVICE_NAME variables have already been loaded by check_uninstall_dir
    local docker_compose_file=""

    # --- Look for .yml or .yaml ---
    if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
        docker_compose_file="$INSTALL_DIR/docker-compose.yml"
        log_info "Docker Compose file found: ${BLUE}docker-compose.yml${NC}"
    elif [[ -f "$INSTALL_DIR/docker-compose.yaml" ]]; then
        docker_compose_file="$INSTALL_DIR/docker-compose.yaml"
        log_info "Docker Compose file found: ${BLUE}docker-compose.yaml${NC}"
    else
        log_warn "No Docker Compose file (docker-compose.yml or docker-compose.yaml) found in '$INSTALL_DIR'."
    fi
    
    # --- Collect information to display ---
    local actions_list=()
    local volumes_to_remove_display=""

    actions_list+=("Systemd service to be removed: ${BLUE}'$SYSTEMD_SERVICE_NAME'${NC}")

    # --- CHANGE HERE: New volume detection logic ---
    if [[ -n "$docker_compose_file" && -f "$docker_compose_file" ]]; then
        local project_name=$(grep -oP '^name:\s*\K[a-zA-Z0-9_-]+' "$docker_compose_file" | head -1)
        if [[ -z "$project_name" ]]; then
            log_warn "Project 'name:' not found in Docker Compose. Using the folder name as a prefix (may not be accurate)."
            project_name=$(basename "$INSTALL_DIR")
        fi
        log_info "Docker Compose project name for volume prefix: ${BLUE}$project_name${NC}"

        local detected_volumes=()
        local in_volumes_block=false
        
        # Use AWK to analyze the volumes block
        # AWK iterates line by line.
        # - Sets 'in_volumes_block' to true when it finds 'volumes:' with no indentation.
        # - Sets 'in_volumes_block' to false when it finds a line with 0 or 1 space of indentation that is not 'volumes:'
        # - Within the volumes block, it takes lines with 2 spaces of indentation and a ':' (volume name)
        while IFS= read -r line; do
            # Trim leading/trailing whitespace and check indentation
            local trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local leading_spaces=${#line}
            leading_spaces=$((leading_spaces - ${#trimmed_line}))

            if [[ "$in_volumes_block" == false ]]; then
                if [[ "$trimmed_line" == "volumes:" && "$leading_spaces" == 0 ]]; then
                    in_volumes_block=true
                fi
            else # We are in the volumes block
                if [[ "$leading_spaces" == 2 && "$trimmed_line" =~ ^[a-zA-Z0-9_-]+:$ ]]; then
                    local vol_name=$(echo "$trimmed_line" | sed 's/://')
                    detected_volumes+=("$vol_name")
                elif [[ "$leading_spaces" -lt 2 && "$trimmed_line" != "volumes:" ]]; then
                    # Exit the volumes block if the indentation is less than 2 and it's not the word "volumes:" itself
                    in_volumes_block=false
                fi
            fi
        done < "$docker_compose_file"

        # Add the project prefix to the detected volumes
        local prefixed_volumes=()
        for vol in "${detected_volumes[@]}"; do
            prefixed_volumes+=("${project_name}_${vol}")
        done

        if [[ ${#prefixed_volumes[@]} -gt 0 ]]; then
            log_info "Volumes detected in the Docker Compose file:"
            for vol in "${prefixed_volumes[@]}"; do
                volumes_to_remove_display+="   - ${BLUE}$vol${NC}\n"
            done
            actions_list+=("Named Docker volumes to be excluded:\n$volumes_to_remove_display")
        else
            actions_list+=("No named Docker volumes found for exclusion in this Docker Compose file.")
        fi
    else
        actions_list+=("No valid Docker Compose file found. It will not be possible to automatically remove Docker containers/volumes.")
    fi
    # --- END OF CHANGE ---

    actions_list+=("Installation folder to be deleted: ${BLUE}'$INSTALL_DIR'${NC}")

    # --- Display summary of actions ---
    echo ""
    log_info "The following actions will be performed during uninstallation:"
    echo "-----------------------------------------------------------"
    for action in "${actions_list[@]}"; do
        echo -e "${GREEN}- $action${NC}"
    done
    echo "-----------------------------------------------------------"
    echo ""

    # --- Warning message in red ---
    echo -e "${RED}======================================================================================${NC}"
    echo -e "${RED}!!! W A R N I N G !!!${NC}"
    echo -e "${RED}The deletion of Docker volumes WILL CAUSE IRREVERSIBLE LOSS of ALL database data${NC}"
    echo -e "${RED}and any other persistent information from the containers.${NC}"
    echo -e "${RED}The removal of the installation folder will also DELETE ALL configurations, logs, and project files.${NC}"
    echo -e "${RED}This data CANNOT BE RECOVERED after uninstallation.${NC}"
    echo -e "${RED}======================================================================================${NC}"
    echo ""

    # --- Ask for final confirmation ---
    confirm_action

    log_info "Starting uninstallation operations..."

    # 1. Stop and disable the systemd service
    log_info "1. Stopping and disabling systemd service '$SYSTEMD_SERVICE_NAME'..."
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        systemctl stop "$SYSTEMD_SERVICE_NAME"
        log_info "Service stopped."
    else
        log_warn "Service '$SYSTEMD_SERVICE_NAME' is not active."
    fi
    if systemctl is-enabled --quiet "$SYSTEMD_SERVICE_NAME"; then
        systemctl disable "$SYSTEMD_SERVICE_NAME"
        log_info "Service disabled."
    else
        log_warn "Service '$SYSTEMD_SERVICE_NAME' is not enabled."
    fi
    rm -f "/etc/systemd/system/$SYSTEMD_SERVICE_NAME"
    systemctl daemon-reload
    log_info "Systemd service removed."

    # 2. Stop and remove Docker containers and volumes
    if [[ -n "$docker_compose_file" && -f "$docker_compose_file" ]]; then # Check if the file was found for execution
        log_info "2. Stopping and removing Docker containers and networks defined in '$docker_compose_file'..."
        pushd "$INSTALL_DIR" > /dev/null # Enter the project folder
        docker compose --file "$docker_compose_file" down
        log_info "Containers and networks removed."

        log_info "3. Removing detected named Docker volumes..."
        # Use the same volume detection logic for removal
        local project_name_for_removal=$(grep -oP '^name:\s*\K[a-zA-Z0-9_-]+' "$docker_compose_file" | head -1)
        if [[ -z "$project_name_for_removal" ]]; then
            project_name_for_removal=$(basename "$INSTALL_DIR")
        fi

        local detected_volumes_for_removal=()
        local in_volumes_block_for_removal=false
        while IFS= read -r line; do
            local trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local leading_spaces=${#line}
            leading_spaces=$((leading_spaces - ${#trimmed_line}))

            if [[ "$in_volumes_block_for_removal" == false ]]; then
                if [[ "$trimmed_line" == "volumes:" && "$leading_spaces" == 0 ]]; then
                    in_volumes_block_for_removal=true
                fi
            else
                if [[ "$leading_spaces" == 2 && "$trimmed_line" =~ ^[a-zA-Z0-9_-]+:$ ]]; then
                    local vol_name=$(echo "$trimmed_line" | sed 's/://')
                    detected_volumes_for_removal+=("${project_name_for_removal}_${vol_name}")
                elif [[ "$leading_spaces" -lt 2 && "$trimmed_line" != "volumes:" ]]; then
                    in_volumes_block_for_removal=false
                fi
            fi
        done < "$docker_compose_file"

        if [[ ${#detected_volumes_for_removal[@]} -gt 0 ]]; then
            for vol in "${detected_volumes_for_removal[@]}"; do
                log_info "   - Removing volume: $vol"
                docker volume rm "$vol" || log_warn "Failed to remove volume '$vol'. It may not exist or be in use."
            done
            log_info "Named Docker volumes processed."
        else
            log_info "No named Docker volumes found to remove."
        fi
        popd > /dev/null # Exit the project folder
    else
        log_warn "No valid Docker Compose file found. Could not remove Docker containers/volumes."
    fi

    # 4. Remove the installation folder
    if [[ -d "$INSTALL_DIR" ]]; then
        log_info "4. Removing installation folder '$INSTALL_DIR'..."
        rm -rf "$INSTALL_DIR"
        log_info "Installation folder removed."
    else
        log_warn "Installation folder '$INSTALL_DIR' not found to remove."
    fi

    log_info "==============================================="
    log_info "✅ Uninstallation completed successfully!"
    log_info "==============================================="
}

main "$@"

