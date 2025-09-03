# home-server

## Project Overview

This repository contains the configuration for a personal home server, designed to run essential home services using Docker containers. The goal is to create a centralized, modular, and easily reproducible environment for managing network services, home automation, and data storage.

By using a single `docker-compose.yml` file, all services and their dependencies are defined in one place, simplifying setup and ensuring consistent deployment. This approach allows for easy scalability by adding or removing services as needed.

## Key Services

The project currently includes configurations for the following services:

* **[Home Assistant](https://www.home-assistant.io/):** A powerful open-source home automation platform for local control of smart devices.
* **[Pi-Hole](https://pi-hole.net/):** A network-wide ad and tracker blocking DNS server.
* **[PostgreSQL](https://www.postgresql.org/):** A robust relational database for data storage.
* **[nginx](https://nginx.org/):** A high-performance web server, reverse proxy, and load balancer.

**Future services:** The modular design allows for the easy addition of other services, such as media servers, file storage, and more.

---

## Getting Started

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

2.  Create the `.env` file in the project's root folder and configure the necessary environment variables. Check the `README.md` files within each service's subfolder for a list of required variables.

3.  With the `.env` file configured, run the following command from the project's root directory to start the containers:

    ```bash
    docker compose up -d
    ```

---

## Automated Deployment with systemd

To ensure your services start automatically on system boot, you can use `systemd`.

1.  Copy the `homeserver.service` file to the `systemd` configuration folder:

    ```bash
    sudo cp homeserver.service /etc/systemd/system/
    ```

2.  Adjust the `WorkingDirectory` line in the `/etc/systemd/system/homeserver.service` file to your project's correct path. If you cloned it to `/home/daniel/home-server`, the path should be:

    ```ini
    WorkingDirectory=/home/daniel/home-server
    ```

3.  Reload `systemd` so it recognizes the new service and enables it to start on boot:

    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable homeserver.service
    ```

4.  To start the service immediately, run:

    ```bash
    sudo systemctl start homeserver.service
    ```

---

## Project Status

The project is currently under development.