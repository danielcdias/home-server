#!/bin/bash

# Configurações
PROJECT_DIR="/home/daniel/home-server"
SERVICE_NAME="homeserver"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
        log_error "Este script deve ser executado como root!"
        exit 1
    fi
}

# Função para detectar o comando docker compose correto
detect_docker_compose() {
    # Primeiro tenta docker compose (com espaço) - versão mais nova
    if command -v docker > /dev/null && docker compose version > /dev/null 2>&1; then
        echo "docker compose"
    # Depois tenta docker-compose (com hífen) - versão mais antiga
    elif command -v docker-compose > /dev/null; then
        echo "docker-compose"
    else
        log_error "Docker Compose não está instalado!"
        exit 1
    fi
}

# Função para verificar se o diretório do projeto existe
check_project_dir() {
    if [[ ! -d "$PROJECT_DIR" ]]; then
        log_error "Diretório do projeto não encontrado: $PROJECT_DIR"
        exit 1
    fi
    log_info "Diretório do projeto encontrado: $PROJECT_DIR"
}

# Função para verificar se os scripts de start/stop existem
check_service_scripts() {
    if [[ ! -f "$PROJECT_DIR/start-service.sh" ]]; then
        log_error "Script de start não encontrado: $PROJECT_DIR/start-service.sh"
        exit 1
    fi
    
    if [[ ! -f "$PROJECT_DIR/stop-service.sh" ]]; then
        log_error "Script de stop não encontrado: $PROJECT_DIR/stop-service.sh"
        exit 1
    fi
    
    # Tornar os scripts executáveis
    chmod +x "$PROJECT_DIR/start-service.sh" "$PROJECT_DIR/stop-service.sh"
    log_info "Scripts de serviço verificados e tornados executáveis"
}

# Função para copiar o arquivo de serviço existente
copy_service_file() {
    log_info "Verificando arquivo de serviço existente..."
    
    # Verificar se o arquivo de serviço já existe no projeto
    LOCAL_SERVICE_FILE="$PROJECT_DIR/homeserver.service"
    
    if [[ ! -f "$LOCAL_SERVICE_FILE" ]]; then
        log_error "Arquivo de serviço não encontrado: $LOCAL_SERVICE_FILE"
        exit 1
    fi
    
    # Copiar para o systemd
    cp "$LOCAL_SERVICE_FILE" "$SERVICE_FILE"
    
    if [[ $? -eq 0 ]]; then
        log_info "Arquivo de serviço copiado: $SERVICE_FILE"
        chmod 644 "$SERVICE_FILE"
        
        # Verificar se o arquivo foi copiado corretamente
        if [[ -f "$SERVICE_FILE" ]]; then
            log_info "Conteúdo do arquivo de serviço:"
            echo "----------------------------------------"
            cat "$SERVICE_FILE"
            echo "----------------------------------------"
        fi
    else
        log_error "Falha ao copiar arquivo de serviço!"
        exit 1
    fi
}

# Função para configurar o serviço
setup_service() {
    log_info "Configurando serviço systemd..."
    
    # Recarregar systemd
    systemctl daemon-reload
    if [[ $? -ne 0 ]]; then
        log_error "Falha ao recarregar systemd!"
        exit 1
    fi
    
    # Habilitar serviço
    systemctl enable "$SERVICE_NAME"
    if [[ $? -ne 0 ]]; then
        log_error "Falha ao habilitar serviço!"
        exit 1
    fi
    
    log_info "Serviço habilitado para inicialização automática"
}

# Função para gerar certificados
generate_certificates() {
    log_info "Gerando certificados SSL..."
    
    # Navegar para o diretório do projeto
    cd "$PROJECT_DIR" || exit 1
    
    # Verificar se o script generate-certs.sh existe
    if [[ ! -f "generate-certs.sh" ]]; then
        log_error "Script generate-certs.sh não encontrado em $PROJECT_DIR"
        exit 1
    fi
    
    # Tornar executável e executar
    chmod +x generate-certs.sh
    ./generate-certs.sh
    
    if [[ $? -eq 0 ]]; then
        log_info "Certificados gerados com sucesso!"
    else
        log_error "Falha ao gerar certificados!"
        exit 1
    fi
}

# Função para verificar dependências
check_dependencies() {
    log_info "Verificando dependências..."
    
    # Verificar docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado!"
        exit 1
    fi
    
    # Verificar docker compose (usando a função de detecção)
    DOCKER_COMPOSE_CMD=$(detect_docker_compose)
    log_info "Comando Docker Compose detectado: $DOCKER_COMPOSE_CMD"
    
    # Verificar openssl
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL não está instalado!"
        exit 1
    fi
    
    log_info "Todas as dependências verificadas com sucesso"
}

# Função para mostrar resumo da instalação
show_summary() {
    echo ""
    log_info "=== INSTALAÇÃO CONCLUÍDA ==="
    log_info "Projeto: $PROJECT_DIR"
    log_info "Serviço: $SERVICE_NAME"
    log_info "Arquivo de serviço: $SERVICE_FILE"
    log_info "Script start: $PROJECT_DIR/start-service.sh"
    log_info "Script stop: $PROJECT_DIR/stop-service.sh"
    log_info "Docker Compose: $DOCKER_COMPOSE_CMD"
    echo ""
    log_info "Comandos úteis:"
    log_info "  Iniciar serviço: systemctl start $SERVICE_NAME"
    log_info "  Parar serviço: systemctl stop $SERVICE_NAME"
    log_info "  Status do serviço: systemctl status $SERVICE_NAME"
    log_info "  Ver logs: journalctl -u $SERVICE_NAME -f"
    log_info "  Recarregar serviço: systemctl daemon-reload"
    echo ""
    log_info "Certificados gerados em: $PROJECT_DIR/nginx/ssl/"
    log_info "Lembre-se de instalar o ca.crt em todos os dispositivos!"
    echo ""
}

# Função principal
main() {
    echo -e "${GREEN}"
    echo "=========================================="
    echo "    INSTALAÇÃO DO HOME SERVER"
    echo "    (Usando service file existente)"
    echo "=========================================="
    echo -e "${NC}"
    
    # Verificações iniciais
    check_root
    check_dependencies
    check_project_dir
    check_service_scripts
    
    # Executar passos de instalação
    copy_service_file
    setup_service
    generate_certificates
    
    # Mostrar resumo
    show_summary
    
    log_info "Instalação concluída com sucesso! 🚀"
    log_warn "Execute 'systemctl start $SERVICE_NAME' para iniciar os serviços"
}

# Executar função principal
main "$@"
