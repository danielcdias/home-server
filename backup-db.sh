#!/bin/bash

# ==============================================================================
# Script to back up all databases from a PostgreSQL Docker container,
# including the 'postgres' database.
#
# This script loads its configuration from a .env file located in the
# same directory.
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must be run as root!"
    exit 1
fi

# Set the path to the .env file (looks in the same directory as the script)
ENV_FILE="$(dirname "$0")/.env"

if [ -f "${ENV_FILE}" ]; then
    echo "Loading environment variables from ${ENV_FILE}..."
    # Export variables from .env to the script's execution environment
    # Ignores commented and empty lines.
    export $(grep -v '^#' "${ENV_FILE}" | grep -v '^$' | xargs)
else
    echo "WARNING: .env file not found at ${ENV_FILE}. Using existing environment variables or default values."
fi

# Name or ID of the Docker container where PostgreSQL is running.
readonly POSTGRES_CONTAINER_NAME="${POSTGRES_CONTAINER_NAME:-postgres}"

# PostgreSQL user with permissions to access all databases.
# The 'postgres' user is generally the default and most secure choice.
readonly POSTGRES_USER="${POSTGRES_USER:-postgres}"

# Directory on the HOST (outside the container) where backup files will be saved.
# This directory will be created if it does not exist.
readonly BACKUP_DIR="/var/backups/pg_container"

echo "--- Starting PostgreSQL backup process ---"
echo "Date and Time: $(date +'%Y-%m-%d %H:%M:%S')"
echo "Container: ${POSTGRES_CONTAINER_NAME}"
echo "PostgreSQL User: ${POSTGRES_USER}"

# 1. Check if Docker is running
if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
    echo "[ERROR] Docker is not running or could not be found."
    exit 1
fi

# 2. Ensure the backup directory exists on the host
echo "Checking backup directory: ${BACKUP_DIR}"
if ! mkdir -p "${BACKUP_DIR}"; then
    echo "[ERROR] Failed to create backup directory. Check permissions."
    exit 1
fi
echo "Backup directory ensured."

# 3. Get the list of all databases from the container
# This SQL command excludes template databases, which do not need to be backed up.
echo "Fetching database list from container '${POSTGRES_CONTAINER_NAME}'..."
DB_LIST=$(docker exec "${POSTGRES_CONTAINER_NAME}" psql -U "${POSTGRES_USER}" -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false;")

# Check if the database list was successfully retrieved
if [ -z "${DB_LIST}" ]; then
  echo "[ERROR] Could not retrieve database list. Check the container name, user, and if the container is running."
  exit 1
fi

echo "Databases to be backed up:"
echo "${DB_LIST}"
echo "----------------------------------------"

# 4. Loop through each database and perform the backup
for DB_NAME in $DB_LIST; do
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  # Remove any invalid characters from the database name for the filename.
  CLEAN_DB_NAME=$(echo "${DB_NAME}" | tr -d '\r')
  FILE_PATH="${BACKUP_DIR}/${CLEAN_DB_NAME}-${TIMESTAMP}.sql.gz"

  echo "Backing up database '${CLEAN_DB_NAME}' to '${FILE_PATH}'..."

  # Execute pg_dump inside the container, pipe the output to gzip on the host.
  # The output of gzip is then redirected to the backup file on the host.
  docker exec "${POSTGRES_CONTAINER_NAME}" pg_dump -U "${POSTGRES_USER}" -d "${CLEAN_DB_NAME}" | gzip > "${FILE_PATH}"

  # Check the exit status of the pg_dump command (the first command in the pipe).
  # ${PIPESTATUS[0]} is a special Bash variable that holds the exit code of the first command in a pipeline.
  if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "[SUCCESS] Backup of database '${CLEAN_DB_NAME}' completed successfully."
  else
    echo "[FAILURE] An error occurred during the backup of database '${CLEAN_DB_NAME}'. Removing partial file."
    # Remove the backup file that may have been partially created.
    rm -f "${FILE_PATH}"
    exit 1
  fi
  echo "----------------------------------------"
done

echo "--- Backup process finished. ---"

