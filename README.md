# home-server

## Project Overview

This repository contains the configuration for a personal home server, designed to run essential home services using Docker containers. The goal is to create a centralized, modular, and easily reproducible environment for managing network services, home automation, and data storage.

By using a single `docker-compose.yml` file, all services and their dependencies are defined in one place, simplifying setup and ensuring consistent deployment. This approach allows for easy scalability by adding or removing services as needed.

## Key Services

The project currently includes configurations for the following services:

* **[PostgreSQL](https://www.postgresql.org/):** A robust relational database for data storage. It's used by Home Assistant and can be used by any other service or customized application you build.
* **[nginx](https://nginx.org/):** A high-performance web server, reverse proxy, and load balancer. The main role of nginx is to provide forwarding from any web interface the services may have to a subdomain, ensuring all services use HTTPS when accessed.
* **[Pi-Hole](https://pi-hole.net/):** A network-wide ad and tracker blocking DNS server.
* **[Home Assistant](https://www.home-assistant.io/):** A powerful open-source home automation platform for local control of smart devices.
* **[Komodo](https://komo.do/):** A tool to provide structure for managing your servers, builds, deployments, and automated procedures.
* **[Webmin](https://webmin.com/):** A system administration tool for Unix-like servers and services.

**Future services:** The modular design allows for the easy addition of other services, such as media servers, file storage, and more.

## Domain and Subdomains

This project creates the domain `homeserver` and subdomains for all services that have a web interface:

- `pihole.homeserver`: Pi-Hole
- `ha.homeserver`: Home Assistant
- `komodo.homeserver`: Komodo
- `webmin.homeserver`: Webmin

This mean that your server hostname should be `homeserver`. Or you can change this code to use the hostname you already have configured. In the future we plan to change the installation script to ask the hostname to be used.

The setup also generates a self-signed certificate for the domain and subdomains, with a `ca.crt` file that can be added to your devices to make the HTTPS addresses recognized by browsers within your domestic network.

All the services above are forwarded by nginx to their respective subdomains.

## Getting Started

### Prerequisites

To get started with this project, you need to have the following software installed on your server:

* [**Docker**](https://docs.docker.com/get-docker/)
* [**Docker Compose**](https://docs.docker.com/compose/install/)
* [**Webmin**](https://webmin.com/download/)

### Installation and Deployment

1.  Clone this repository to your home server:

    ```bash
    git clone https://github.com/danielcdias/home-server.git
    cd home-server
    ```

2.  Create the `.env` file in the root folder with the following variables:

| Variable | Description | Example |
| :--- | :--- | :--- |
| `TZ` | The [timezone code](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) for your country/area. | `America/Sao_Paulo` |
| `POSTGRES_DB` | Database root db (usually postgres). | `postgres` |
| `POSTGRES_USER` | Database root username. | `postgres` |
| `POSTGRES_PASSWORD` | Database root password. | `a_strong_password` |
| `PIHOLE_WEB_PASSWORD` | Password to access Pi-Hole's Web Admin page. | `a_strong_password` |
| `HA_POSTGRES_USER` | Home Assistant Postgres username. | `homeassistant` |
| `HA_POSTGRES_PASSWORD` | Home Assistant Postgres password. | `a_strong_password` |
| `HA_POSTGRES_DB_NAME` | Home Assistant database name to be created in Postgres. | `home_assistant` |
| `HA_DB_URL` | URL for Home Assistant access to Postgres database, using the variables defined above. | `postgresql://<username>:<password>@postgres/<db_name>` |

3. Create the `./postgres/config/config.json` file with the databases to be created when PostgreSQL starts. For example, the Home Assistant database:

```json
[
  {
    "db_name": "home_assistant",
    "user": "homeassistant",
    "password": "a_strong_password"
  }
]
```
⚠️ **ATTENTION!** he database name, username, and password information for Home Assistant in the config.json file MUST BE THE SAME as defined in the `.env` file.


4.  With both `.env` and `./postgres/config/config.json` files configured, run the `./install.sh` script with sudo, providing the complete path to the `home-server` project folder created in step 1 as an argument:

```bash
sudo ./install.sh /home/johndoe/home-server
```

The `./install.sh` script will:
- Check if prerequisites are installed, like Docker
- Create a service in `systemctl` configuration named homeserver.service to automate startup
- Configure Webmin to work being forwarded by nginx
- Generate certificates for all domains and subdomains

5. After installation, you can reboot your system to check if the `homeserver.service` will start automatically,  or you can start it manually with:

```bash
cd\<project_folder>
sudo docker compose up -d
```

Depending on your Docker version, the command might be `docker-compose` instead of `docker compose`.

## Available Services

This home server deployment provides the following services:

### Web Interfaces
All web-accessible services are available through a secure reverse proxy with HTTPS encryption:

- **Central Dashboard**: https://homeserver/ - Overview page with links to all services.
- **Pi-hole**: https://pihole.homeserver - Network-wide ad blocking and DNS management.
- **Home Assistant**: https://ha.homeserver - Home automation and smart device control panel.
- **Komodo**: https://komodo.homeserver - Server management and deployment automation interface.
- **Webmin**: https://webmin.homeserver - System administration web console

### Network Services
- **PostgreSQL Database**: Accessible on port 5432 for database operations and application connectivity.
- **Pi-hole DNS Service**: Listening on port 53 for network-wide DNS resolution and filtering.

## Additional Configuration Notes

### Webmin Setup

Webmin is configured through the install script to work with the nginx reverse proxy. The script modifies Webmin's configuration to allow secure access through the reverse proxy.

### SSL Certificates

The self-signed certificates generated during installation need to be trusted on your devices:

1. Locate the ca.crt file generated by the install script (`<project_folder>/nginx/ssl/ca.crt`).
2. Import it into your device's trusted root certificate authorities.
3. This will prevent browser security warnings when accessing services.

### Network Considerations

- Ensure your router is configured to use Pi-Hole as the DNS server for your network.
- The nginx reverse proxy uses port 80 (HTTP) and 443 (HTTPS).
- Make sure these ports are forwarded correctly if accessing from outside your network.

### Backup Recommendations

Regularly backup:

- PostgreSQL databases using pg_dump.
- Docker volumes containing application data.
- Configuration files from the repository.

## Project Status

The project is currently under development.

## Contributing

Feel free to submit issues and enhancement requests for improving this home server setup.

## License

This project is open source and available under the MIT License.