#!/bin/bash

# Configurações padrão
DEFAULT_PROJECT_DIR="/home/daniel/home-server"
SERVICE_NAME="homeserver"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 [--path CAMINHO_DO_PROJETO]"
    echo "  --path CAMINHO_DO_PROJETO  Diretório do projeto (padrão: $DEFAULT_PROJECT_DIR)"
    exit 1
}

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

# Função para parsear argumentos
parse_arguments() {
    PROJECT_DIR="$DEFAULT_PROJECT_DIR"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --path)
                PROJECT_DIR="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                ;;
            *)
                log_error "Argumento desconhecido: $1"
                show_usage
                ;;
        esac
    done
    
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
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
    if command -v docker > /dev/null && docker compose version > /dev/null 2>&1; then
        echo "docker compose"
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
    log_info "Diretório do projeto: $PROJECT_DIR"
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
    
    chmod +x "$PROJECT_DIR/start-service.sh" "$PROJECT_DIR/stop-service.sh"
    log_info "Scripts de serviço verificados e tornados executáveis"
}

# Função para criar arquivo de serviço dinamicamente
create_service_file() {
    local service_file="$1"
    local project_dir="$2"
    
    log_info "Criando arquivo de serviço em: $service_file"
    
    cat > "$service_file" << EOF
[Unit]
Description=Home Server
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$project_dir
ExecStart=$project_dir/start-service.sh --path "$project_dir"
ExecStop=$project_dir/stop-service.sh --path "$project_dir"
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    if [[ $? -eq 0 ]]; then
        log_info "Arquivo de serviço criado com sucesso"
        chmod 644 "$service_file"
        
        # Mostrar conteúdo do arquivo criado
        log_info "Conteúdo do arquivo de serviço:"
        echo "----------------------------------------"
        cat "$service_file"
        echo "----------------------------------------"
    else
        log_error "Falha ao criar arquivo de serviço!"
        exit 1
    fi
}

# Função para configurar o serviço
setup_service() {
    log_info "Configurando serviço systemd..."
    
    systemctl daemon-reload || { log_error "Falha ao recarregar systemd!"; exit 1; }
    systemctl enable "$SERVICE_NAME" || { log_error "Falha ao habilitar serviço!"; exit 1; }
    
    log_info "Serviço habilitado para inicialização automática"
}

# Função para gerar certificados
generate_certificates() {
    log_info "Gerando certificados SSL..."
    
    cd "$PROJECT_DIR" || exit 1
    
    if [[ ! -f "generate-certs.sh" ]]; then
        log_error "Script generate-certs.sh não encontrado em $PROJECT_DIR"
        exit 1
    fi
    
    chmod +x generate-certs.sh
    ./generate-certs.sh --path "$PROJECT_DIR"
    
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
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado!"
        exit 1
    fi
    
    DOCKER_COMPOSE_CMD=$(detect_docker_compose)
    log_info "Comando Docker Compose detectado: $DOCKER_COMPOSE_CMD"
    
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
    log_info "Docker Compose: $DOCKER_COMPOSE_CMD"
    echo ""
    log_info "Comandos úteis:"
    log_info "  Iniciar serviço: systemctl start $SERVICE_NAME"
    log_info "  Parar serviço: systemctl stop $SERVICE_NAME"
    log_info "  Status: systemctl status $SERVICE_NAME"
    echo ""
    log_info "Certificados em: $PROJECT_DIR/nginx/ssl/"
    echo ""
}

# Função principal
main() {
    echo -e "${GREEN}"
    echo "=========================================="
    echo "    INSTALAÇÃO DO HOME SERVER"
    echo "=========================================="
    echo -e "${NC}"
    
    parse_arguments "$@"
    check_root
    check_dependencies
    check_project_dir
    check_service_scripts
    
    # Criar arquivo de serviço dinamicamente
    create_service_file "$SERVICE_FILE" "$PROJECT_DIR"
    setup_service
    generate_certificates
    
    show_summary
    
    log_info "Instalação concluída com sucesso! 🚀"
    log_warn "Execute 'systemctl start $SERVICE_NAME' para iniciar os serviços"
}

main "$@"