# PostgreSQL

## Overview

This folder contains the Docker Compose configuration for the PostgreSQL database service. This database is intended to be used by other services on your home server, such as Home Assistant and Speedtest-Tracker.

## Configuration

Before starting the container, create a `.env` file in this folder with the following variables.

| Variable | Description | Example |
| :--- | :--- | :--- |
| `POSTGRES_USER` | The user for the database. This will be the username used by other services. | `ha_user` |
| `POSTGRES_PASSWORD` | A strong password for the database user. | `a-strong-password` |
| `POSTGRES_DB_NAME` | The name of the database to be created for your services. | `homeassistant` |

## Deployment

1.  Create the `.env` file with the variables above.
2.  Run the following command to start the database service:

    ```bash
    docker-compose up -d
    ```

## Access

-   **Connection String:** Other services can connect to this database using a connection string like: `postgresql://<user>:<password>@<container_name>:5432/<db_name>`.
-   **External Network:** Ensure this service is connected to the same external network as other services that need to use it.
