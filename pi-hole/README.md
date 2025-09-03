# Pi-Hole

## Overview

This folder contains the Docker Compose configuration for running Pi-Hole as a DNS server. Pi-Hole acts as a network-wide ad blocker, protecting all devices on your home network.

The setup is configured to expose the necessary DNS ports and a web interface for managing the service.

## Configuration

Before starting the container, edit the `.env` file in the root of the project to include the following variables.

| Variable | Description | Example |
| :--- | :--- | :--- |
| `PIHOLE_WEB_PASSWORD` | The password to access the Pi-hole web interface. | `a-strong-password` |
| `FTLCONF_DNS_LISTENING_MODE` | Configures Pi-hole's DNS listening mode. It should be `'all'` for Docker's default `bridge` network. | `'all'` |
| `TZ` | The timezone for the container. | `'America/Sao_Paulo'` |

## Access

-   **Web Interface:** Access the Pi-hole web interface at `http://pihole.<your-server-hostname>`.
-   **DNS:** Configure the DNS settings of your router or individual devices to point to `<your-server-ip>`.
