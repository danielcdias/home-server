#!/bin/bash

# Configurações
PROJECT_DIR="/home/daniel/home-server"
PROJECT_NAME="home-server"  # Nome do projeto no docker-compose
RUNTIME_DIR="$PROJECT_DIR/runtime_config"

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

# Função para listar e remover volumes do projeto Docker
clean_docker_volumes() {
    log_info "Procurando volumes Docker do projeto '$PROJECT_NAME'..."
    
    # Listar todos os volumes Docker e filtrar os do projeto
    VOLUMES=$(docker volume ls -q | grep "^${PROJECT_NAME}_" | sort)
    
    if [[ -z "$VOLUMES" ]]; then
        log_warn "Nenhum volume Docker encontrado para o projeto '$PROJECT_NAME'"
        
        # Tentar encontrar volumes sem prefixo (para projetos mais antigos)
        log_info "Procurando volumes sem prefixo..."
        VOLUMES=$(docker volume ls -q | grep -E "(mongo-data|mongo-config|postgres_data)" | sort)
    fi
    
    if [[ -z "$VOLUMES" ]]; then
        log_warn "Nenhum volume Docker encontrado"
        return
    fi
    
    log_info "Volumes Docker encontrados:"
    echo "$VOLUMES" | while read volume; do
        echo "   - $volume"
    done
    
    # Remover cada volume
    echo "$VOLUMES" | while read volume; do
        log_info "Removendo volume Docker: $volume"
        if docker volume rm -f "$volume" 2>/dev/null; then
            log_info "✅ Volume $volume removido"
        else
            log_warn "⚠️  Não foi possível remover volume: $volume (pode estar em uso)"
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

