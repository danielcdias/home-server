#!/bin/bash

# Configurações padrão
DEFAULT_INSTALL_DIR="/opt/home-server"
DEFAULT_HOSTNAME=$(hostname | cut -d'.' -f1)
if [[ -z "$DEFAULT_HOSTNAME" || "$DEFAULT_HOSTNAME" == "localhost" ]]; then
    DEFAULT_HOSTNAME="homeserver"
fi
DEFAULT_DOMAIN_SUFFIX="lan"
SERVICE_NAME="homeserver"
# O diretório do script (onde o clone do git está)
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo "  --install-dir CAMINHO         Diretório de instalação final (padrão: $DEFAULT_INSTALL_DIR)"
    echo "  --hostname NOME_DO_HOST       Nome do host (padrão: $DEFAULT_HOSTNAME)"
    echo "  --domain-suffix SUFIXO        Sufixo do domínio (padrão: $DEFAULT_DOMAIN_SUFFIX)"
    echo "  --non-interactive             Modo não interativo (usa padrões ou argumentos)"
    echo "  --help, -h                    Mostrar esta ajuda"
    exit 1
}

# Funções de log (log_info, log_warn, log_error)
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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

# Função para perguntar sobre Webmin
prompt_webmin() {
    echo -e "${BLUE}🤖 Suporte ao Webmin${NC}"
    read -p "$(echo -e "${BLUE}   Deseja habilitar o suporte ao Webmin (requer instalação se não existir)? (S/n): ${NC}")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_WEBMIN=false
        echo -e "${YELLOW}   ⚠️  Suporte ao Webmin desabilitado${NC}"
    else
        ENABLE_WEBMIN=true
        echo -e "${GREEN}   ✅ Suporte ao Webmin habilitado${NC}"
    fi
    echo
}

# Função para parsear argumentos
parse_arguments() {
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    SERVER_HOSTNAME="$DEFAULT_HOSTNAME"
    DOMAIN_SUFFIX="$DEFAULT_DOMAIN_SUFFIX"
    ENABLE_WEBMIN=true
    local non_interactive=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir) INSTALL_DIR="$2"; shift 2 ;;
            --hostname) SERVER_HOSTNAME="$2"; shift 2 ;;
            --domain-suffix) DOMAIN_SUFFIX="$2"; shift 2 ;;
            --non-interactive) non_interactive=true; shift ;;
            --help|-h) show_usage ;;
            *) log_error "Argumento desconhecido: $1"; show_usage ;;
        esac
    done
    
    if [[ "$non_interactive" == false ]]; then
        echo -e "${GREEN}==========================================${NC}"
        echo -e "${GREEN}    CONFIGURAÇÃO INTERATIVA DO HOME SERVER    ${NC}"
        echo -e "${GREEN}==========================================${NC}\n"
        
        prompt_with_default "Informe o diretório de instalação final" "$DEFAULT_INSTALL_DIR" "INSTALL_DIR"
        prompt_with_default "Informe o nome do host (domínio principal)" "$DEFAULT_HOSTNAME" "SERVER_HOSTNAME"
        prompt_with_default "Informe o sufixo do domínio (lan, local, etc.)" "$DEFAULT_DOMAIN_SUFFIX" "DOMAIN_SUFFIX"
        prompt_webmin
        
        echo -e "${GREEN}📋 Resumo da configuração:${NC}"
        echo -e "   📦 Diretório de instalação: ${GREEN}$INSTALL_DIR${NC}"
        echo -e "   🌐 Hostname: ${GREEN}$SERVER_HOSTNAME${NC}"
        echo -e "   🔗 Domínio Completo: ${GREEN}$SERVER_HOSTNAME.$DOMAIN_SUFFIX${NC}"
        echo -e "   🖥️  Webmin: ${GREEN}$([[ "$ENABLE_WEBMIN" == true ]] && echo "Habilitado" || echo "Desabilitado")${NC}\n"
        
        confirm_action "O projeto será instalado e configurado no diretório de destino."
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

# Função para verificar dependências
check_dependencies() {
    log_info "Verificando dependências..."
    if ! command -v docker &> /dev/null; then log_error "Docker não está instalado!"; exit 1; fi
    if ! command -v docker-compose &> /dev/null && ! (command -v docker &> /dev/null && docker compose version &> /dev/null); then log_error "Docker Compose não está instalado!"; exit 1; fi
    if ! command -v openssl &> /dev/null; then log_error "OpenSSL não está instalado!"; exit 1; fi
    log_info "Dependências verificadas."
}

# Função para preparar o diretório de instalação
prepare_install_dir() {
    log_info "Preparando diretório de instalação: $INSTALL_DIR"
    if [ -d "$INSTALL_DIR" ]; then
        log_warn "O diretório de instalação já existe."
        confirm_action "Isso pode sobrescrever arquivos existentes. Deseja continuar?"
    fi
    mkdir -p "$INSTALL_DIR" || { log_error "Falha ao criar diretório de instalação!"; exit 1; }
    
    log_info "Copiando arquivos do projeto de $SOURCE_DIR para $INSTALL_DIR..."
    # Usar rsync para mais controle e para excluir o próprio diretório git
    rsync -av --progress "$SOURCE_DIR/" "$INSTALL_DIR/" --exclude ".git" --exclude ".gitignore"
    
    # Criar diretórios que podem não existir no fonte mas são necessários no runtime
    mkdir -p "$INSTALL_DIR/runtime_config/etc-pihole"
    mkdir -p "$INSTALL_DIR/runtime_config/home-assistant/config"
    log_info "Diretório de instalação preparado com sucesso."
}

# Função para gerar o arquivo de configuração .env
generate_config_env() {
    local config_file="$1/config.env"
    log_info "Gerando arquivo de configuração de ambiente em $config_file"
    
    cat > "$config_file" << EOF
# Este arquivo é gerado automaticamente pelo install.sh
# Não edite manualmente, pois suas alterações serão perdidas na próxima instalação.

# Configurações de Domínio e Rede
SERVER_HOSTNAME=$SERVER_HOSTNAME
DOMAIN_SUFFIX=$DOMAIN_SUFFIX
NGINX_IPV4=172.20.0.100

# Configurações de Componentes
ENABLE_WEBMIN=$ENABLE_WEBMIN
EOF
    log_info "✅ Arquivo config.env gerado."
}

# Função para processar templates
process_templates() {
    log_info "Processando arquivos de template..."

    # Processar index.html.tpl -> index.html
    local index_tpl="$INSTALL_DIR/nginx/html/index.html.tpl"
    local index_html="$INSTALL_DIR/nginx/html/index.html"
    if [[ -f "$index_tpl" ]]; then
        # Substituir placeholders de domínio
        sed "s/{{SERVER_HOSTNAME}}/$SERVER_HOSTNAME/g; s/{{DOMAIN_SUFFIX}}/$DOMAIN_SUFFIX/g" "$index_tpl" > "$index_html"
        # Remover link do Webmin se desabilitado
        if [[ "$ENABLE_WEBMIN" == false ]]; then
            sed -i '/webmin/d' "$index_html"
        fi
        log_info "✅ Template nginx/html/index.html.tpl processado."
    fi

    # Processar reverse-proxy.conf.tpl
    # O processamento final será feito pelo envsubst no contêiner,
    # mas removemos o bloco do Webmin aqui se necessário.
    local nginx_tpl="$INSTALL_DIR/nginx/reverse-proxy.conf.tpl"
    if [[ "$ENABLE_WEBMIN" == false && -f "$nginx_tpl" ]]; then
        # Usar awk para remover o bloco do Webmin de forma segura
        awk '/# Proxy para o Webmin/,/}/ {next} 1' "$nginx_tpl" > "${nginx_tpl}.tmp" && mv "${nginx_tpl}.tmp" "$nginx_tpl"
        log_info "✅ Bloco do Webmin removido de nginx/reverse-proxy.conf.tpl."
    fi
}

# Função para criar o arquivo de serviço
create_service_file() {
    log_info "Criando arquivo de serviço em: $SERVICE_FILE"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Home Server Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$SERVICE_FILE"
    log_info "Arquivo de serviço criado."
}

# Função para configurar e habilitar o serviço
setup_service() {
    log_info "Configurando serviço systemd..."
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    log_info "Serviço $SERVICE_NAME habilitado para inicialização automática."
}

# Função para gerar certificados
generate_certificates() {
    local cert_script="$INSTALL_DIR/generate-certs.sh"
    if [[ ! -f "$cert_script" ]]; then
        log_error "Script generate-certs.sh não encontrado em $INSTALL_DIR";
        exit 1;
    fi
    
    log_info "Gerando certificados SSL..."
    chmod +x "$cert_script"
    # Passar todos os parâmetros para o script de certificados
    "$cert_script" --path "$INSTALL_DIR" --hostname "$SERVER_HOSTNAME" --domain-suffix "$DOMAIN_SUFFIX" --webmin "$ENABLE_WEBMIN"
}

# Função principal
main() {
    check_root
    parse_arguments "$@"
    check_dependencies
    
    prepare_install_dir
    generate_config_env "$INSTALL_DIR"
    process_templates

    # Verificar se o .env principal existe e alertar o usuário
    if [[ ! -f "$INSTALL_DIR/.env" ]]; then
        log_warn "Arquivo .env com segredos não encontrado em $INSTALL_DIR."
        log_warn "Copie o .env.example para .env e preencha as senhas antes de iniciar o serviço."
    fi
    
    # Opcional: Instalar e configurar Webmin aqui se necessário
    # if [[ "$ENABLE_WEBMIN" == true ]]; then ... fi

    create_service_file
    setup_service
    generate_certificates
    
    echo ""
    log_info "=== INSTALAÇÃO CONCLUÍDA ==="
    log_info "Os arquivos de execução estão em: $INSTALL_DIR"
    log_info "A configuração do ambiente está em: $INSTALL_DIR/config.env"
    log_info "Lembre-se de configurar os segredos em: $INSTALL_DIR/.env"
    log_info "Serviço systemd '$SERVICE_NAME' foi criado e habilitado."
    echo ""
    log_warn "Execute 'systemctl start $SERVICE_NAME' para iniciar os serviços."
    log_info "Acesse o dashboard em: https://$SERVER_HOSTNAME.$DOMAIN_SUFFIX"
    log_info "Instalação finalizada com sucesso! 🚀"
}

main "$@"
