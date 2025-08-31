# home-server

## Project Overview

This repository contains the configuration for a personal home server, designed to run essential home services using Docker containers. The goal is to create a centralized, modular, and easily reproducible environment for managing network services, home automation, and data storage.

By leveraging Docker Compose, all services and their dependencies are defined in configuration files, simplifying setup and ensuring consistent deployment across different environments. This approach allows for easy scaling by adding or removing services as needed.

## Key Features

The project currently includes configurations for the following services:

 **[Home Assistant](https://www.home-assistant.io/):** A powerful open-source home automation platform for local control of smart devices.
* **[Pi-Hole](https://pi-hole.net/):** A network-wide ad and tracker blocking DNS server.
* **[PostgreSQL](https://www.postgresql.org/):** A robust relational database for data storage.

**Future services:** The modular design allows for the easy addition of other services, such as media servers, file storage, and more.

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

2.  Navigate to the folder of the service you want to set up (e.g., `home-assistant/` or `pi-hole/`). **Each service folder contains its own `README.md` file with detailed instructions and a list of necessary configurations, including required variables for the `.env` file.**

3.  Once the service is configured, run the following command from the root directory to start the containers:

    ```bash
    docker-compose up -d
    ```

## Automated Deployment

This project uses an automated deployment mechanism to manage the startup of services. Instead of running docker-compose commands manually for each service, a single script handles the entire orchestration.

The mechanism works as follows:

* The script `deploy.sh` automatically finds subfolders containing a `docker-compose.yml` and a prio.txt file.
* The `prio.txt` file contains a number from 0 to 100, which defines the startup priority. A lower number means a higher priority, ensuring that dependent services (like databases) start before the applications that rely on them.
* The script combines the files in the correct order and runs the final `docker-compose up -d` command.

#### How to Deploy

1. Make sure the deploy.sh script has execute permissions:

```
chmod +x deploy.sh
```

2. Place a `prio.txt` file with a number (0-100) inside each service's folder (e.g., `postgres/prio.txt`). This determines the startup order.

3. Run the following command from the root directory of the project:

```
./deploy.sh
```

## Project Status

The project is currently under development. All listed services are configured, but they may require further testing and fine-tuning.

## Contributions

Contributions, feedback, and suggestions are welcome. If you encounter any issues or have ideas for improvements, please open an issue in this repository.

## Developer

**Daniel Dias**
* **Contact:** daniel.dias@gmail.com