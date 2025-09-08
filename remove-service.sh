#!/bin/bash

# Configurações
SERVICE_NAME="homeserver"

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

# Função para remover o serviço
remove_service() {
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    log_info "Verificando serviço: $SERVICE_NAME"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "Parando serviço..."
        systemctl stop "$SERVICE_NAME"
    else
        log_warn "Serviço não está em execução"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        log_info "Desabilitando serviço..."
        systemctl disable "$SERVICE_NAME"
    else
        log_warn "Serviço não estava habilitado"
    fi
    
    if [[ -f "$SERVICE_FILE" ]]; then
        log_info "Removendo arquivo de serviço: $SERVICE_FILE"
        rm -f "$SERVICE_FILE"
    else
        log_warn "Arquivo de serviço não encontrado: $SERVICE_FILE"
    fi
    
    systemctl daemon-reload
    systemctl reset-failed
    
    log_info "Serviço removido com sucesso"
}

# Função principal
main() {
    echo -e "${GREEN}"
    echo "========================================"
    echo "    REMOÇÃO DE SERVIÇO SYSTEMD"
    echo "========================================"
    echo -e "${NC}"
    
    check_root
    remove_service
    
    echo -e "${GREEN}✅ Serviço '$SERVICE_NAME' removido do systemd${NC}"
}

main "$@"
