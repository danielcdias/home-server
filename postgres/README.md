# PostgreSQL

## Overview

This folder contains the Docker Compose configuration for the PostgreSQL database service. This database is intended to be used by other services on your home server, such as Home Assistant and Speedtest-Tracker.

## Configuration

Before starting the container, edit the `.env` file in the root of the project to include the following variables.

| Variable | Description | Example |
| :--- | :--- | :--- |
| `POSTGRES_USER` | The user for the database. This will be the username used by other services. | `ha_user` |
| `POSTGRES_PASSWORD` | A strong password for the database user. | `a-strong-password` |
| `POSTGRES_DB_NAME` | The name of the database to be created for your services. | `homeassistant` |

## Automated Database and User Configuration

To automate the creation of specific databases and users for each service, you can use a JSON configuration file.

### 1. Create the `config.json` file

Create a folder named `config` and, inside it, a file called `config.json`. This file will contain the details of each database and user that the container should create on its first startup.

**Example** `config.json`:

```
[
  {
    "db_name": "home_assistant_db",
    "user": "ha_user",
    "password": "a_strong_password"
  }
]

```

### 2. The `init.sh` Script

This container is configured to run an initialization script called `init.sh` on its first startup. This script:

1. Verifies the connection to the PostgreSQL server.
2. Reads the `config.json` file.
3. Iterates through each entry in the file.
4. Creates the corresponding database and user if they do not already exist.
5. Grants the necessary privileges to the user on the respective database.

This ensures that databases for each service are created automatically, following security best practices of not using the main user.

## Deployment

1. Create the .`env` and `config.json` files with your respective variables and configurations.
2. Run the deploy script from the project's root folder. The `deploy.sh` script will start all services, including PostgreSQL, in the correct order.

## Access

-   **Connection String (Other Services):** Other services can connect to this database using a connection string like: `postgresql://<user>:<password>@<container_name>:5432/<db_name>`.
-   **External Access (Development)** : Port `5432` is exposed on the container, allowing external clients like **PgAdmin4** to connect from your host machine, using `localhost` or the server's IP as the host.
