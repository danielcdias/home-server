#!/bin/bash

# Configuração padrão
DEFAULT_PROJECT_DIR="/home/daniel/home-server"

# Parsear argumentos
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

# Verificar se o diretório existe
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Erro: Diretório do projeto não encontrado: $PROJECT_DIR"
    exit 1
fi

# Detectar comando docker compose
if command -v docker > /dev/null && docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose > /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo "Docker Compose não encontrado!"
    exit 1
fi

cd "$PROJECT_DIR" || exit 1
echo "Iniciando serviços em: $PROJECT_DIR"
$DOCKER_COMPOSE_CMD up -d
