#!/bin/bash

# Default configuration
DEFAULT_PROJECT_DIR="/home/daniel/home-server"

# Parse arguments
PROJECT_DIR="$DEFAULT_PROJECT_DIR"
while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            PROJECT_DIR="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Check if the directory exists
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: Project directory not found: $PROJECT_DIR"
    exit 1
fi

# Detect docker compose command
if command -v docker > /dev/null && docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose > /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo "Docker Compose not found!"
    exit 1
fi

cd "$PROJECT_DIR" || exit 1
echo "Stopping services in: $PROJECT_DIR"
$DOCKER_COMPOSE_CMD down
