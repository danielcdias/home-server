# Home Assistant

## Overview

This folder contains the configuration for the Home Assistant service. Home Assistant is an open-source home automation platform that puts local control and privacy first.

This setup is configured to connect to an external PostgreSQL database and uses a custom entrypoint script to automatically install the Home Assistant Community Store (HACS) on the first run.

## Prerequisites

-   A running Docker container with a PostgreSQL database.
-   The PostgreSQL container must be connected to an external Docker network named `homelab_network`.
-   A `.env` file containing the required environment variables.
-   The `docker-entrypoint.sh` script (see below).

## Configuration

Before starting the container, edit the `.env` file in the root of the project to include the following variables.

| Variable | Description | Example |
| :--- | :--- | :--- |
| `TZ` | The timezone for the container. | `America/Sao_Paulo` |
| `POSTGRES_USER` | The PostgreSQL database user. | `ha_user` |
| `POSTGRES_PASSWORD` | The password for the PostgreSQL user. | `a-strong-password` |
| `POSTGRES_DB_NAME` | The name of the database to use. | `homeassistant` |

## Notes

-   The first run may take longer as Home Assistant downloads all dependencies and runs the HACS installation script.
-   The `docker-entrypoint.sh` script is designed to run only the HACS installation on the first boot. Subsequent restarts will be faster.
