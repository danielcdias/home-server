#!/bin/bash

# Home Assistant configuration directory
CONFIG_DIR="/config"
# HACS destination directory
HACS_DIR="${CONFIG_DIR}/custom_components/hacs"

# Function to install HACS more robustly
# https://hacs.xyz/docs/use/download/download/#to-download-hacs-container
install_hacs() {
  echo "HACS not found. Starting installation..."

  # mkdir -p "${HACS_DIR}"
  cd "${CONFIG_DIR}"

  wget -O - https://get.hacs.xyz | bash -

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

# Start the main Home Assistant service
echo "Starting Home Assistant..."
# exec python3 -m homeassistant --config "${CONFIG_DIR}" "$@"
exec /init

