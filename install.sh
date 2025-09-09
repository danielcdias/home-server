#!/bin/bash

# Configurações padrão
DEFAULT_PROJECT_DIR="/home/daniel/home-server"
DEFAULT_HOSTNAME=$(hostname | cut -d'.' -f1)
if [[ -z "$DEFAULT_HOSTNAME" || "$DEFAULT_HOSTNAME" == "localhost" ]]; then
    DEFAULT_HOSTNAME="homeserver"
fi
DEFAULT_DOMAIN_SUFFIX="lan"
SERVICE_NAME="homeserver"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBMIN_CONFIG_DIR="/etc/webmin"
WEBMIN_ALLOW_NETWORKS="172.20.0.0/24 10.1.1.0/24"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 [OPÇÕES]"
    echo "Opções:"
    echo "  --path CAMINHO_DO_PROJETO    Diretório do projeto (padrão: $DEFAULT_PROJECT_DIR)"
    echo "  --hostname NOME_DO_HOST      Nome do host (padrão: $DEFAULT_HOSTNAME)"
    echo "  --domain-suffix SUFIXO       Sufixo do domínio (padrão: $DEFAULT_DOMAIN_SUFFIX)"
    echo "  --non-interactive            Modo não interativo (usa padrões ou argumentos)"
    echo "  --help, -h                   Mostrar esta ajuda"
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

# Função para prompt com valor padrão
prompt_with_default() {
    local message="$1"
    local default_value="$2"
    local variable_name="$3"
    
    echo -e "${BLUE}🤖 ${message}${NC}"
    read -p "$(echo -e "${BLUE}   (pressione ENTER para '${default_value}'): ${NC}")" user_input
    
    if [[ -z "$user_input" ]]; then
        eval "$variable_name=\"$default_value\""
        echo -e "${GREEN}   ✅ Usando: ${default_value}${NC}"
    else
        eval "$variable_name=\"$user_input\""
        echo -e "${GREEN}   ✅ Usando: ${user_input}${NC}"
    fi
    echo
}

# Função para confirmar ação
confirm_action() {
    local message="$1"
    
    echo -e "${YELLOW}⚠️  ${message}${NC}"
    read -p "$(echo -e "${YELLOW}   Tem certeza que deseja continuar? (s/N): ${NC}")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${GREEN}Operação cancelada.${NC}"
        exit 0
    fi
}

# Função para verificar se Webmin está instalado
check_webmin_installed() {
    if systemctl is-active --quiet webmin 2>/dev/null || \
       pgrep -x webmin >/dev/null 2>&1 || \
       [[ -f /usr/share/webmin/miniserv.pl ]] || \
       [[ -f /etc/webmin/miniserv.conf ]]; then
        return 0  # Webmin está instalado
    else
        return 1  # Webmin não está instalado
    fi
}

# Função para perguntar sobre Webmin
prompt_webmin() {
    echo -e "${BLUE}🤖 Suporte ao Webmin${NC}"
    echo -e "${BLUE}   O Webmin é uma interface web para administração do sistema${NC}"
    
    if check_webmin_installed; then
        echo -e "${GREEN}   ✅ Webmin detectado no sistema${NC}"
        read -p "$(echo -e "${BLUE}   Deseja configurar suporte ao Webmin? (S/n): ${NC}")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            ENABLE_WEBMIN=false
            echo -e "${YELLOW}   ⚠️  Suporte ao Webmin desabilitado${NC}"
        else
            ENABLE_WEBMIN=true
            echo -e "${GREEN}   ✅ Suporte ao Webmin habilitado${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠️  Webmin não encontrado no sistema${NC}"
        read -p "$(echo -e "${BLUE}   Deseja instalar e configurar o Webmin? (s/N): ${NC}")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            ENABLE_WEBMIN=true
            echo -e "${GREEN}   ✅ Suporte ao Webmin habilitado (será instalado)${NC}"
        else
            ENABLE_WEBMIN=false
            echo -e "${YELLOW}   ⚠️  Suporte ao Webmin desabilitado${NC}"
        fi
    fi
    echo
}

# Função para instalar Webmin se necessário
install_webmin_if_needed() {
    if [[ "$ENABLE_WEBMIN" == true ]] && ! check_webmin_installed; then
        echo -e "${BLUE}🤖 Instalando Webmin...${NC}"
        
        # Verificar distribuição
        if [[ -f /etc/debian_version ]]; then
            # Debian/Ubuntu
            echo -e "${GREEN}   Detectado Debian/Ubuntu${NC}"
            apt-get update
            apt-get install -y webmin
        elif [[ -f /etc/redhat-release ]]; then
            # RHEL/CentOS
            echo -e "${GREEN}   Detectado RHEL/CentOS${NC}"
            # Adicionar repositório do Webmin
            cat > /etc/yum.repos.d/webmin.repo << EOF
[Webmin]
name=Webmin Distribution Neutral
baseurl=https://download.webmin.com/download/yum
enabled=1
gpgcheck=1
gpgkey=https://download.webmin.com/jcameron-key.asc
EOF
            yum install -y webmin
        else
            echo -e "${YELLOW}   ⚠️  Distribuição não suportada para instalação automática do Webmin${NC}"
            echo -e "${YELLOW}   Instale o Webmin manualmente e execute novamente o script${NC}"
            ENABLE_WEBMIN=false
            return 1
        fi
        
        if systemctl is-active --quiet webmin; then
            echo -e "${GREEN}   ✅ Webmin instalado e iniciado com sucesso${NC}"
        else
            echo -e "${YELLOW}   ⚠️  Webmin instalado mas não iniciado. Iniciando...${NC}"
            systemctl start webmin
            systemctl enable webmin
        fi
    fi
}

# Função para parsear argumentos
parse_arguments() {
    local non_interactive=false
    PROJECT_DIR="$DEFAULT_PROJECT_DIR"
    SERVER_HOSTNAME="$DEFAULT_HOSTNAME"
    DOMAIN_SUFFIX="$DEFAULT_DOMAIN_SUFFIX"
    ENABLE_WEBMIN=true  # Padrão é true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --path)
                PROJECT_DIR="$2"
                shift 2
                ;;
            --hostname)
                SERVER_HOSTNAME="$2"
                shift 2
                ;;
            --domain-suffix)
                DOMAIN_SUFFIX="$2"
                shift 2
                ;;
            --non-interactive)
                non_interactive=true
                shift
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
    
    # Modo interativo se não for non-interactive
    if [[ "$non_interactive" == false ]]; then
        echo -e "${GREEN}"
        echo "=========================================="
        echo "    CONFIGURAÇÃO INTERATIVA DO HOME SERVER"
        echo "=========================================="
        echo -e "${NC}"
        
        prompt_with_default "Informe o caminho completo da pasta do projeto" "$DEFAULT_PROJECT_DIR" "PROJECT_DIR"
        prompt_with_default "Informe o nome do host desta máquina para ser usado como domínio" "$DEFAULT_HOSTNAME" "SERVER_HOSTNAME"
        prompt_with_default "Informe o sufixo do domínio (local, lan, home, etc.)" "$DEFAULT_DOMAIN_SUFFIX" "DOMAIN_SUFFIX"
        
        # Perguntar sobre Webmin
        prompt_webmin
        
        echo -e "${GREEN}📋 Resumo da configuração:${NC}"
        echo -e "   📁 Diretório: ${GREEN}$PROJECT_DIR${NC}"
        echo -e "   🌐 Hostname: ${GREEN}$SERVER_HOSTNAME${NC}"
        echo -e "   🔗 Domínio: ${GREEN}$SERVER_HOSTNAME.$DOMAIN_SUFFIX${NC}"
        echo -e "   🖥️  Webmin: ${GREEN}$([[ "$ENABLE_WEBMIN" == true ]] && echo "Habilitado" || echo "Desabilitado")${NC}"
        echo
        
        confirm_action "Esta configuração será aplicada em todos os arquivos do projeto."
    else
        log_info "Modo não interativo ativado"
        log_info "Configuração: Path=$PROJECT_DIR, Hostname=$SERVER_HOSTNAME, Domínio=$DOMAIN_SUFFIX"
    fi
    
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

# Função para configurar Webmin (CONFIGURAÇÃO ORIGINAL RESTAURADA)
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
    
    # Configurar /etc/webmin/config - MODIFICAÇÃO APENAS DAS CONFIGURAÇÕES NECESSÁRIAS
    if [[ -f "$WEBMIN_CONFIG_DIR/config" ]]; then
        # Atualizar ou adicionar configurações específicas
        if ! grep -q "^allow=" "$WEBMIN_CONFIG_DIR/config"; then
            echo "allow=$WEBMIN_ALLOW_NETWORKS" >> "$WEBMIN_CONFIG_DIR/config"
        else
            sed -i "s/^allow=.*/allow=$WEBMIN_ALLOW_NETWORKS/" "$WEBMIN_CONFIG_DIR/config"
        fi
        
        if ! grep -q "^referers=" "$WEBMIN_CONFIG_DIR/config"; then
            echo "referers=webmin.homeserver" >> "$WEBMIN_CONFIG_DIR/config"
        else
            sed -i "s/^referers=.*/referers=webmin.homeserver/" "$WEBMIN_CONFIG_DIR/config"
        fi
        
        if ! grep -q "^noreferers=" "$WEBMIN_CONFIG_DIR/config"; then
            echo "noreferers=*" >> "$WEBMIN_CONFIG_DIR/config"
        else
            sed -i "s/^noreferers=.*/noreferers=*/" "$WEBMIN_CONFIG_DIR/config"
        fi
        
        if ! grep -q "^ssl_redirect=" "$WEBMIN_CONFIG_DIR/config"; then
            echo "ssl_redirect=0" >> "$WEBMIN_CONFIG_DIR/config"
        else
            sed -i "s/^ssl_redirect=.*/ssl_redirect=0/" "$WEBMIN_CONFIG_DIR/config"
        fi
        
        if ! grep -q "^no_ssl_redirect=" "$WEBMIN_CONFIG_DIR/config"; then
            echo "no_ssl_redirect=1" >> "$WEBMIN_CONFIG_DIR/config"
        else
            sed -i "s/^no_ssl_redirect=.*/no_ssl_redirect=1/" "$WEBMIN_CONFIG_DIR/config"
        fi
        
        # Remover configurações conflitantes se existirem
        sed -i '/^webprefix=/d' "$WEBMIN_CONFIG_DIR/config"
        sed -i '/^relative_links=/d' "$WEBMIN_CONFIG_DIR/config"
        
    else
        log_error "Arquivo config não encontrado!"
        return 1
    fi
    
    # Configurar /etc/webmin/miniserv.conf (já está correto)
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

# Função para atualizar arquivos de configuração
update_config_files() {
    local project_dir="$1"
    local hostname="$2"
    local domain_suffix="$3"
    
    log_info "Atualizando arquivos de configuração..."
    
    # 1. Atualizar generate-certs.sh
    if [[ -f "$project_dir/generate-certs.sh" ]]; then
        sed -i "s/SERVER_HOSTNAME=.*/SERVER_HOSTNAME=\"$hostname\"/" "$project_dir/generate-certs.sh"
        sed -i "s/DOMAIN_SUFFIX=.*/DOMAIN_SUFFIX=\"$domain_suffix\"/" "$project_dir/generate-certs.sh"
        
        # Atualizar suporte a Webmin no generate-certs.sh
        if [[ "$ENABLE_WEBMIN" == true ]]; then
            sed -i "s/ENABLE_WEBMIN=.*/ENABLE_WEBMIN=true/" "$project_dir/generate-certs.sh"
        else
            sed -i "s/ENABLE_WEBMIN=.*/ENABLE_WEBMIN=false/" "$project_dir/generate-certs.sh"
        fi
        
        log_info "✅ generate-certs.sh atualizado"
    fi
    
    # 2. Atualizar docker-compose.yaml (Pi-hole DNS)
    if [[ -f "$project_dir/docker-compose.yaml" ]]; then
        sed -i "s|address=/[a-zA-Z0-9_\-]*/|address=/$hostname.$domain_suffix/|g" "$project_dir/docker-compose.yaml"
        log_info "✅ docker-compose.yaml atualizado"
    fi
    
    # 3. Atualizar nginx/reverse-proxy.conf (com suporte opcional ao Webmin)
    if [[ -f "$project_dir/nginx/reverse-proxy.conf" ]]; then
        # Backup do arquivo original
        cp "$project_dir/nginx/reverse-proxy.conf" "$project_dir/nginx/reverse-proxy.conf.backup"
        
        # Atualizar domínios
        sed -i "s/[a-zA-Z0-9_\-]*\.lan/$hostname.$domain_suffix/g" "$project_dir/nginx/reverse-proxy.conf"
        sed -i "s/server_name [a-zA-Z0-9_\-]*;/server_name $hostname $hostname.$domain_suffix;/" "$project_dir/nginx/reverse-proxy.conf"
        
        # Remover bloco do Webmin se desabilitado
        if [[ "$ENABLE_WEBMIN" == false ]]; then
            sed -i '/# Proxy para o Webmin/,/}/d' "$project_dir/nginx/reverse-proxy.conf"
            log_info "✅ nginx/reverse-proxy.conf atualizado (sem Webmin)"
        else
            log_info "✅ nginx/reverse-proxy.conf atualizado (com Webmin)"
        fi
    fi
    
    # 4. Atualizar nginx/html/index.html
    if [[ -f "$project_dir/nginx/html/index.html" ]]; then
        sed -i "s/homeserver/$hostname/g" "$project_dir/nginx/html/index.html"
        sed -i "s/homeserver\.lan/$hostname.$domain_suffix/g" "$project_dir/nginx/html/index.html"
        log_info "✅ nginx/html/index.html atualizado"
    fi
    
    # 5. Configurar Webmin se habilitado
    if [[ "$ENABLE_WEBMIN" == true ]]; then
        configure_webmin
    fi
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
    ./generate-certs.sh --path "$PROJECT_DIR" --hostname "$SERVER_HOSTNAME" --domain-suffix "$DOMAIN_SUFFIX" --webmin "$ENABLE_WEBMIN"
    
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
    log_info "Hostname: $SERVER_HOSTNAME"
    log_info "Domínio: $SERVER_HOSTNAME.$DOMAIN_SUFFIX"
    log_info "Webmin: $([[ "$ENABLE_WEBMIN" == true ]] && echo "Habilitado" || echo "Desabilitado")"
    log_info "Serviço: $SERVICE_NAME"
    log_info "Arquivo de serviço: $SERVICE_FILE"
    log_info "Docker Compose: $DOCKER_COMPOSE_CMD"
    echo ""
    log_info "Comandos úteis:"
    log_info "  Iniciar serviço: systemctl start $SERVICE_NAME"
    log_info "  Parar serviço: systemctl stop $SERVICE_NAME"
    log_info "  Status: systemctl status $SERVICE_NAME"
    echo ""
    log_info "Acesse: https://$SERVER_HOSTNAME.$DOMAIN_SUFFIX"
    log_info "Certificados em: $PROJECT_DIR/nginx/ssl/"
    echo ""
}

# Função principal
main() {
    parse_arguments "$@"
    check_root
    check_dependencies
    check_project_dir
    check_service_scripts
    
    # Instalar Webmin se necessário
    install_webmin_if_needed
    
    # Atualizar arquivos de configuração com o hostname e domínio
    update_config_files "$PROJECT_DIR" "$SERVER_HOSTNAME" "$DOMAIN_SUFFIX"
    
    # Criar arquivo de serviço dinamicamente
    create_service_file "$SERVICE_FILE" "$PROJECT_DIR"
    setup_service
    generate_certificates
    
    show_summary
    
    log_info "Instalação concluída com sucesso! 🚀"
    log_warn "Execute 'systemctl start $SERVICE_NAME' para iniciar os serviços"
}

main "$@"
