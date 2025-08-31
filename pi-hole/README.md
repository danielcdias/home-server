# Pi-Hole

## Overview

This folder contains the Docker Compose configuration for running Pi-Hole as a DNS server. Pi-Hole acts as a network-wide ad blocker, protecting all devices on your home network.

The setup is configured to expose the necessary DNS ports and a web interface for managing the service.

## Configuration

Before deployment, create a `.env` file in this folder with the following variables.

| Variable | Description | Example |
| :--- | :--- | :--- |
| `PIHOLE_WEB_PASSWORD` | The password to access the Pi-hole web interface. | `a-strong-password` |
| `FTLCONF_dns_listeningMode` | Configures Pi-hole's DNS listening mode. It should be `'all'` for Docker's default `bridge` network. | `'all'` |
| `TZ` | The timezone for the container. | `'America/Sao_Paulo'` |

## Deployment

1.  Create the `.env` file with the variables above.
2.  Run the following command to deploy the service:

    ```bash
    docker-compose up -d
    ```

## Access

-   **Web Interface:** Access the Pi-hole web interface at `http://<your-server-ip>:10001`.
-   **DNS:** Configure the DNS settings of your router or individual devices to point to `<your-server-ip>`.

## Notes on your `docker-compose.yml`

Your `docker-compose.yml` for Pi-Hole is well-structured and aligns with best practices. The use of an `.env` file and `unless-stopped` is good. The port mappings for the web interface are customized to avoid conflicts with other services, which is an excellent practice.