#!/bin/bash

# Home Assistant configuration directory
CONFIG_DIR="/config"
# HACS destination directory
HACS_DIR="${CONFIG_DIR}/custom_components/hacs"

# Function to install HACS more robustly
install_hacs() {
  echo "HACS not found. Starting installation..."

  # Navigate to the custom components directory
  mkdir -p "${HACS_DIR}"
  cd "${HACS_DIR}"

  # Download the zip file of the latest HACS version
  # Using a fixed URL for the zip, which is more reliable than pip
  wget -q -O hacs.zip "https://github.com/hacs/integration/archive/main.zip"

  # Unzip the contents of the file
  unzip -q hacs.zip

  # Move the files to the correct directory
  mv integration-main/* .

  # Clean up temporary files
  rm -rf integration-main hacs.zip

  # Navigate back to the configuration directory
  cd "${CONFIG_DIR}"

  if [ -d "${HACS_DIR}" ]; then
    echo "HACS installation completed successfully."
  else
    echo "HACS installation failed."
  fi
}

# Check if the HACS directory already exists
if [ ! -d "$HACS_DIR" ]; then
    install_hacs
else
    echo "HACS is already installed. No action needed."
fi

# Create the initial configuration file, if it doesn't exist
if [ ! -f "${CONFIG_DIR}/configuration.yaml" ]; then
    echo "Creating the initial configuration file..."
    cat <<EOF > "${CONFIG_DIR}/configuration.yaml"
# Reverse proxy configuration for Nginx
http:
  server_host:
    - 0.0.0.0
  use_x_forwarded_for: true
  trusted_proxies:
    - 0.0.0.0/0
  login_attempts_threshold: 3
EOF
fi

# Start the main Home Assistant service
echo "Starting Home Assistant..."
exec python3 -m homeassistant --config "${CONFIG_DIR}" "$@"
