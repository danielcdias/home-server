#!/bin/bash

# Configurações
PROJECT_DIR="/home/daniel/home-server"
RUNTIME_DIR="$PROJECT_DIR/runtime_config"
DOCKER_COMPOSE_FILE="$PROJECT_DIR/docker-compose.yaml"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para verificar se é root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado com sudo!"
        exit 1
    fi
}

# Função para limpar runtime_config
clean_runtime_dir() {
    log_info "Verificando diretório de runtime: $RUNTIME_DIR"
    
    if [[ -d "$RUNTIME_DIR" ]]; then
        log_info "Removendo diretório de runtime..."
        rm -rf "$RUNTIME_DIR"
        log_info "Diretório runtime_config removido"
    else
        log_warn "Diretório runtime_config não encontrado"
    fi
}

# Função para remover volumes Docker específicos
clean_docker_volumes() {
    log_info "Verificando volumes Docker do projeto..."
    
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        log_error "Arquivo docker-compose.yaml não encontrado: $DOCKER_COMPOSE_FILE"
        exit 1
    fi
    
    # Lista de volumes definidos no docker-compose.yaml
    VOLUMES=$(grep -E "^\s+[a-zA-Z0-9_-]+:" "$DOCKER_COMPOSE_FILE" | \
              grep -v "name:" | \
              sed 's/^\s*//;s/://' | \
              tr -d ' ' | sort | uniq)
    
    if [[ -z "$VOLUMES" ]]; then
        log_warn "Nenhum volume encontrado no docker-compose.yaml"
        return
    fi
    
    log_info "Volumes encontrados no docker-compose:"
    echo "$VOLUMES" | while read volume; do
        echo "   - $volume"
    done
    
    # Remover cada volume
    echo "$VOLUMES" | while read volume; do
        if docker volume inspect "${volume}" >/dev/null 2>&1; then
            log_info "Removendo volume Docker: $volume"
            docker volume rm -f "$volume" 2>/dev/null || \
            log_warn "Não foi possível remover volume: $volume (pode estar em uso)"
        else
            log_warn "Volume não existe: $volume"
        fi
    done
    
    log_info "Limpeza de volumes Docker concluída"
}

# Função principal
main() {
    echo -e "${GREEN}"
    echo "========================================"
    echo "    LIMPEZA DE RUNTIME E VOLUMES"
    echo "========================================"
    echo -e "${NC}"
    
    check_root
    
    # Confirmar ação
    read -p "Tem certeza que deseja remover runtime_config e volumes Docker? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${GREEN}Operação cancelada.${NC}"
        exit 0
    fi
    
    clean_runtime_dir
    clean_docker_volumes
    
    echo -e "${GREEN}✅ Limpeza de runtime e volumes concluída${NC}"
}

# Executar função principal
main "$@"
