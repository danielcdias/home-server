#!/bin/bash

# Configurações padrão
DEFAULT_PROJECT_DIR="/home/daniel/home-server"
SERVICE_NAME="homeserver"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBMIN_CONFIG_DIR="/etc/webmin"
WEBMIN_ALLOW_NETWORKS="172.20.0.0/24 10.1.1.0/24"

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

# Função para configurar Webmin
configure_webmin() {
    log_info "Configurando Webmin para aceitar conexões do proxy..."
    
    # Verificar se Webmin está instalado
    if [[ ! -d "$WEBMIN_CONFIG_DIR" ]]; then
        log_warn "Webmin não está instalado. Pulando configuração do Webmin."
        return 0
    fi
    
    # Backup dos arquivos originais
    backup_timestamp=$(date +%Y%m%d_%H%M%S)
    if [[ -f "$WEBMIN_CONFIG_DIR/config" ]]; then
        cp "$WEBMIN_CONFIG_DIR/config" "$WEBMIN_CONFIG_DIR/config.backup_$backup_timestamp"
    fi
    if [[ -f "$WEBMIN_CONFIG_DIR/miniserv.conf" ]]; then
        cp "$WEBMIN_CONFIG_DIR/miniserv.conf" "$WEBMIN_CONFIG_DIR/miniserv.conf.backup_$backup_timestamp"
    fi
    
    # Configurar /etc/webmin/config
    cat > "$WEBMIN_CONFIG_DIR/config" << EOF
allow=$WEBMIN_ALLOW_NETWORKS
referers=webmin.homeserver
noreferers=*
ssl_redirect=0
no_ssl_redirect=1
EOF
    
    # Configurar /etc/webmin/miniserv.conf
    if [[ -f "$WEBMIN_CONFIG_DIR/miniserv.conf" ]]; then
        # Remover configurações SSL problemáticas
        sed -i '/^ssl=/d' "$WEBMIN_CONFIG_DIR/miniserv.conf"
        sed -i '/^ssl_keyfile=/d' "$WEBMIN_CONFIG_DIR/miniserv.conf"
        sed -i '/^ssl_certfile=/d' "$WEBMIN_CONFIG_DIR/miniserv.conf"
        sed -i '/^ssl_enforce=/d' "$WEBMIN_CONFIG_DIR/miniserv.conf"
        sed -i '/^ssl_hsts=/d' "$WEBMIN_CONFIG_DIR/miniserv.conf"
        sed -i '/^no_trust_ssl=/d' "$WEBMIN_CONFIG_DIR/miniserv.conf"
        
        # Adicionar/atualizar configurações necessárias
        if ! grep -q "^allow=" "$WEBMIN_CONFIG_DIR/miniserv.conf"; then
            echo "allow=$WEBMIN_ALLOW_NETWORKS" >> "$WEBMIN_CONFIG_DIR/miniserv.conf"
        else
            sed -i "s/^allow=.*/allow=$WEBMIN_ALLOW_NETWORKS/" "$WEBMIN_CONFIG_DIR/miniserv.conf"
        fi
        
        if ! grep -q "^referers=" "$WEBMIN_CONFIG_DIR/miniserv.conf"; then
            echo "referers=webmin.homeserver" >> "$WEBMIN_CONFIG_DIR/miniserv.conf"
        else
            sed -i "s/^referers=.*/referers=webmin.homeserver/" "$WEBMIN_CONFIG_DIR/miniserv.conf"
        fi
        
        if ! grep -q "^trust_real_ip=" "$WEBMIN_CONFIG_DIR/miniserv.conf"; then
            echo "trust_real_ip=1" >> "$WEBMIN_CONFIG_DIR/miniserv.conf"
        else
            sed -i "s/^trust_real_ip=.*/trust_real_ip=1/" "$WEBMIN_CONFIG_DIR/miniserv.conf"
        fi
        
        if ! grep -q "^trusted_proxies=" "$WEBMIN_CONFIG_DIR/miniserv.conf"; then
            echo "trusted_proxies=172.20.0.100" >> "$WEBMIN_CONFIG_DIR/miniserv.conf"
        else
            sed -i "s/^trusted_proxies=.*/trusted_proxies=172.20.0.100/" "$WEBMIN_CONFIG_DIR/miniserv.conf"
        fi
        
        # Garantir bind correto
        sed -i 's/^bind=.*/bind=0.0.0.0/' "$WEBMIN_CONFIG_DIR/miniserv.conf"
        
    else
        log_error "Arquivo miniserv.conf não encontrado!"
        return 1
    fi
    
    log_info "Configuração do Webmin atualizada com sucesso"
    log_info "Redes permitidas: $WEBMIN_ALLOW_NETWORKS"
    
    # Reiniciar Webmin se estiver rodando
    if systemctl is-active --quiet webmin; then
        log_info "Reiniciando Webmin para aplicar configurações..."
        systemctl restart webmin
        if [[ $? -eq 0 ]]; then
            log_info "Webmin reiniciado com sucesso"
        else
            log_warn "Falha ao reiniciar Webmin. Reinicie manualmente: systemctl restart webmin"
        fi
    fi
    
    return 0
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
    log_info "Webmin configurado para redes: $WEBMIN_ALLOW_NETWORKS"
    echo ""
    log_info "Comandos úteis:"
    log_info "  Iniciar serviço: systemctl start $SERVICE_NAME"
    log_info "  Parar serviço: systemctl stop $SERVICE_NAME"
    log_info "  Status: systemctl status $SERVICE_NAME"
    log_info "  Reiniciar Webmin: systemctl restart webmin"
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
    
    # Configurar Webmin
    configure_webmin
    
    # Criar arquivo de serviço dinamicamente
    create_service_file "$SERVICE_FILE" "$PROJECT_DIR"
    setup_service
    generate_certificates
    
    show_summary
    
    log_info "Instalação concluída com sucesso! 🚀"
    log_warn "Execute 'systemctl start $SERVICE_NAME' para iniciar os serviços"
    log_warn "Execute 'systemctl restart webmin' se o Webmin estiver instalado"
}

main "$@"
