# nginx reverse proxy

## Overview

This folder contains the configuration for running **nginx** as a **reverse proxy server** within a Docker container. Its primary purpose is to route incoming web traffic from standard HTTP ports (80 and 443) to different services running on your home server based on their subdomains.

This setup allows you to expose multiple services (like Home Assistant or Pi-Hole) with web interfaces on a single public IP address, using clear, user-friendly URLs (e.g., `ha.home-server` and `pihole.home-server`).

---

## Configuration

The core configuration for the reverse proxy is located in the `reverse-proxy.conf` file. This file uses nginx's notation to define server blocks that listen for specific subdomains and forward the requests to the correct internal container and port.

**Example `reverse-proxy.conf` entry:**

```nginx
server {
    listen 80;
    server_name ha.home-server;

    location / {
        proxy_pass http://home-assistant:8123;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```