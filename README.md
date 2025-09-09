# 🏠🖥️ home-server

## 👁️ Project Overview

This repository contains the configuration for a personal home server, designed to run essential home services using Docker containers. The goal is to create a centralized, modular, and easily reproducible environment for managing network services, home automation, and data storage.

By using a single `docker-compose.yml` file, all services and their dependencies are defined in one place, simplifying setup and ensuring consistent deployment. This approach allows for easy scalability by adding or removing services as needed.

## 🔑 Key Services

The project currently includes configurations for the following services:

* **[PostgreSQL](https://www.postgresql.org/):** A robust relational database for data storage. It's used by Home Assistant and can be used by any other service or customized application you build.
* **[nginx](https://nginx.org/):** A high-performance web server, reverse proxy, and load balancer. The main role of nginx is to provide forwarding from any web interface the services may have to a subdomain, ensuring all services use HTTPS when accessed.
* **[Pi-Hole](https://pi-hole.net/):** A network-wide ad and tracker blocking DNS server.
* **[Home Assistant](https://www.home-assistant.io/):** A powerful open-source home automation platform for local control of smart devices.
* **[Komodo](https://komo.do/):** A tool to provide structure for managing your servers, builds, deployments, and automated procedures.
* **[Webmin](https://webmin.com/):** A system administration tool for Unix-like servers and services (optional).

💡 Webmin support is an optional component selected during installation. While the following documentation references Webmin, you may ignore all related sections if you did not install it.

**Future services:** The modular design allows for the easy addition of other services, such as media servers, file storage, and more.

## 🌐 Domain and Subdomains

The domain for all web services is defined during installation. This project automatically creates the chosen domain and corresponding subdomains for each service with a web interface.

Using the example domain `homeserver`, the following subdomains would be generated:

- `pihole.homeserver` for Pi-Hole
- `ha.homeserver` for Home Assistant
- `komodo.homeserver` for Komodo
- `webmin.homeserver` for Webmin

The chosen domain name must match the system's hostname. This ensures that the server's IP address can be correctly resolved by the local DNS server (Pi-hole), allowing all subdomains and services to be accessible on your home network.

The setup also generates a self-signed certificate for the domain and all subdomains. A `ca.crt` file is provided, which you can install on your devices to ensure browsers recognize the HTTPS certificates within your local network.

All services are proxied through nginx, which routes traffic from these subdomains to their respective applications.

## 🚀 Getting Started

### Prerequisites

To get started with this project, you need to have the following software installed on your server:

* [**Docker**](https://docs.docker.com/get-docker/)
* [**Docker Compose**](https://docs.docker.com/compose/install/)

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

    ⚠️ **ATTENTION!** The database name, username, and password information for Home Assistant in the config.json file MUST BE THE SAME as defined in the `.env` file.

4.  With both `.env` and `./postgres/config/config.json` files configured, run the `./install.sh` script with sudo, providing the complete path to the `home-server` project folder created in step 1 as an argument:

    ```bash
    sudo ./install.sh /home/johndoe/home-server
    ```

    The `./install.sh` script performs the following actions:

    - **Prompts for configuration details**: You will be asked to provide the project's home directory (full path), the domain name (which must match the machine's hostname), and whether to include Webmin support.
    - **Checks for prerequisites**: The script will verify that required software, such as Docker, is installed.
    - **Creates a system service**: A `systemctl` service named `homeserver.service` will be created to manage automatic startup.
    - **Configures Webmin (if selected)**: Webmin will be set up to work behind the nginx reverse proxy.
    - **Generates SSL certificates**: Self-signed certificates will be created for the main domain and all subdomains.

5. After installation, you can reboot your system to check if the `homeserver.service` will start automatically,  or you can start it manually with:

    ```bash
    cd\<project_folder>
    sudo docker compose up -d
    ```

    Depending on your Docker version, the command might be `docker-compose` instead of `docker compose`.

## 📡Available Services

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

## ⚙️ Additional Configuration Notes

### Webmin Setup

If selected during installation, Webmin is automatically configured to work behind the nginx reverse proxy. The script modifies Webmin's configuration to enable secure access through the proxy.

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

## 📊 Project Status

The project is currently under development.

## 🤝 Contributing

Feel free to submit issues and enhancement requests for improving this home server setup.

## 📜 License

This project is open source and available under the MIT License.
