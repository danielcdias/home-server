#!/bin/bash

set -e

echo "Database ready. Creating databases and users..."

# Export the PGPASSWORD environment variable
export PGPASSWORD=${POSTGRES_PASSWORD}

# Read the JSON file using 'jq'
config_json=$(cat /docker-entrypoint-initdb.d/config/config.json)

# Iterate over each JSON object (each set of credentials)
for row in $(echo "${config_json}" | jq -r '.[] | @base64'); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }

    DB_NAME=$(_jq '.db_name')
    DB_USER=$(_jq '.user')
    DB_PASSWORD=$(_jq '.password')

    # Check if the database already exists
    if ! psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
        echo "Creating database: $DB_NAME"
        psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE DATABASE \"$DB_NAME\";"
        
        echo "Creating user: $DB_USER"
        psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"

        echo "Granting privileges on $DB_NAME for $DB_USER"
        psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

        # Add this line to change ownership
        echo "Changing ownership of database '$DB_NAME' to '$DB_USER'"
        psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$DB_NAME" -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
    else
        echo "Database '$DB_NAME' already exists. Skipping creation."
    fi
done

echo "Initial database configuration completed."

# Clear the PGPASSWORD variable to avoid exposing the password
unset PGPASSWORD
