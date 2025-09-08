#!/bin/bash

# Detectar comando docker compose
if command -v docker > /dev/null && docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose > /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo "Docker Compose não encontrado!"
    exit 1
fi

cd /home/daniel/home-server
$DOCKER_COMPOSE_CMD up -d
