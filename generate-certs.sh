#!/bin/bash

# Encerra o script se qualquer comando falhar
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções de log
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 --path CAMINHO_DO_PROJETO --hostname NOME_DO_HOST --domain-suffix SUFIXO [--webmin true|false] [--ip ENDERECO_IP]"
    echo "Argumentos obrigatórios:"
    echo "  --path CAMINHO_DO_PROJETO    Diretório base de instalação (ex: /opt/homeserver)."
    echo "  --hostname NOME_DO_HOST      Nome do host (ex: homeserver)."
    echo "  --domain-suffix SUFIXO       Sufixo do domínio (ex: lan)."
    echo ""
    echo "Argumentos opcionais:"
    echo "  --webmin [true|false]        Habilitar Webmin (padrão: true)."
    echo "  --ip ENDERECO_IP             Endereço IP da máquina host (será detectado se não fornecido)."
    echo "  --help, -h                   Mostrar esta ajuda."
    exit 1
}

# Configurações padrão (apenas para fallback, serão sobrescritas pelo install.sh)
DEFAULT_PROJECT_DIR="/opt/homeserver"
DEFAULT_HOSTNAME=$(hostname | cut -d'.' -f1)
if [[ -z "$DEFAULT_HOSTNAME" || "$DEFAULT_HOSTNAME" == "localhost" ]]; then
    DEFAULT_HOSTNAME="homeserver"
fi
DEFAULT_DOMAIN_SUFFIX="lan"
ENABLE_WEBMIN=true
CERT_DAYS=3650

# Função para parsear argumentos
parse_arguments() {
    PROJECT_DIR="$DEFAULT_PROJECT_DIR"
    SERVER_HOSTNAME="$DEFAULT_HOSTNAME"
    DOMAIN_SUFFIX="$DEFAULT_DOMAIN_SUFFIX"
    ENABLE_WEBMIN=true
    SERVER_IP="" # Será detectado ou preenchido por parâmetro

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
            --webmin)
                if [[ "$2" == "true" ]]; then
                    ENABLE_WEBMIN=true
                elif [[ "$2" == "false" ]]; then
                    ENABLE_WEBMIN=false
                fi
                shift 2
                ;;
            --ip)
                SERVER_IP="$2"
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

    # Detecta o IP se não foi fornecido via --ip
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
        if [[ -z "$SERVER_IP" ]]; then
            log_warn "Não foi possível detectar o IP do host automaticamente. Usando 127.0.0.1 como fallback."
            SERVER_IP="127.0.0.1" # Fallback para evitar erro
        fi
    fi

    NGINX_SSL_DIR="$PROJECT_DIR/nginx/ssl"
    NGINX_CONF_FILE="$PROJECT_DIR/nginx/reverse-proxy.conf"

    log_info "Configuração para Geração de Certificados:"
    echo -e "   - Hostname: ${BLUE}$SERVER_HOSTNAME${NC}"
    echo -e "   - Domínio: ${BLUE}$DOMAIN_SUFFIX${NC}"
    echo -e "   - Webmin: ${BLUE}$ENABLE_WEBMIN${NC}"
    echo -e "   - IP do Servidor: ${BLUE}$SERVER_IP${NC}"
    echo -e "   - Diretório do Projeto: ${BLUE}$PROJECT_DIR${NC}"
    echo -e "   - Diretório SSL do Nginx: ${BLUE}$NGINX_SSL_DIR${NC}"
    echo -e "   - Arquivo de Configuração do Nginx: ${BLUE}$NGINX_CONF_FILE${NC}"
}

# Função para extrair subdomínios do nginx
extract_subdomains() {
    log_info "🔍 Tentando analisar configuração do nginx em $NGINX_CONF_FILE para subdomínios..."
    
    local found_subdomains=""

    if [[ ! -f "$NGINX_CONF_FILE" ]]; then
        log_warn "Arquivo de configuração do nginx NÃO ENCONTRADO em $NGINX_CONF_FILE. Subdomínios serão baseados apenas nos padrões."
        SUBDOMAINS="" # Garante que está vazio
        return # Sai da função, não é um erro fatal
    fi
    
    log_info "Conteúdo do 'server_name' encontrado (para depuração):"
    grep -oP 'server_name\s+\K[^;]+' "$NGINX_CONF_FILE" | tr ' ' '\n' | sed 's/^/   /g'
    
    # Extrair todos os server_name e processá-los
    found_subdomains=$(grep -oP 'server_name\s+\K[^;]+' "$NGINX_CONF_FILE" | \
                       tr ' ' '\n' | \
                       grep -v "^$" | \
                       grep -v "^\s*$" | \
                       sort | uniq)

    log_info "Valores brutos de 'server_name' após grep/sort/uniq:"
    echo "$found_subdomains" | sed 's/^/   /g'

    local processed_subdomains=""
    for name in $found_subdomains; do
        # Remover o hostname base e o sufixo de domínio para isolar apenas o subdomínio
        # Ex: "pihole.homeserver.lan" -> "pihole"
        # Ex: "ha.homeserver" -> "ha"
        local sub=$(echo "$name" | sed "s/\.${SERVER_HOSTNAME}\.${DOMAIN_SUFFIX}//" | sed "s/\.${SERVER_HOSTNAME}//")

        # Se o nome original continha o hostname, e o resultado não é vazio nem o hostname em si
        if [[ "$name" =~ "${SERVER_HOSTNAME}" && -n "$sub" && "$sub" != "$SERVER_HOSTNAME" ]]; then
            # Adicionar apenas se for um subdomínio válido e não for "localhost"
            if [[ "$sub" != "localhost" && "$sub" != "$SERVER_HOSTNAME" && "$sub" != "${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}" ]]; then
                 processed_subdomains+="$sub "
            fi
        fi
    done
    
    # Filtrar "webmin" se estiver desabilitado
    local final_subdomains=""
    for sub in $processed_subdomains; do
        if [[ "$sub" == "webmin" && "$ENABLE_WEBMIN" == "false" ]]; then
            log_warn "⚠️  Webmin desabilitado - ignorando 'webmin' extraído da configuração."
            continue
        fi
        final_subdomains+="$sub "
    done

    SUBDOMAINS=$(echo "$final_subdomains" | xargs) # Limpa espaços extras

    if [[ -z "$SUBDOMAINS" ]]; then
        log_warn "Nenhum subdomínio adicional detectado na configuração do nginx (além dos padrões)."
    else
        log_info "✅ Subdomínios detectados e processados da configuração:"
        for sub in $SUBDOMAINS; do
            echo -e "   - ${BLUE}$sub${NC}"
        done
    fi
}

# Função principal
main() {
    parse_arguments "$@"
    
    log_info "🔐 Iniciando geração de certificado ÚNICO autoassinado..."
    log_info "📅 Validade: $((CERT_DAYS/365)) anos"
    echo ""

    # Extrair subdomínios automaticamente - DEVE SER EXECUTADO PRIMEIRO PARA ATUALIZAR $SUBDOMAINS
    extract_subdomains

    # Criar lista de Subject Alternative Names (SAN)
    # Inclui o hostname base COM e SEM o sufixo .lan, localhost e o IP
    declare -a SAN_ARRAY # Usar array para evitar problemas de concatenação de string
    SAN_ARRAY+=("DNS:$SERVER_HOSTNAME") # homeserver
    SAN_ARRAY+=("DNS:$SERVER_HOSTNAME.$DOMAIN_SUFFIX") # homeserver.lan
    SAN_ARRAY+=("DNS:localhost")
    SAN_ARRAY+=("IP:$SERVER_IP")

    # Adicionar subdomínios COMUNS POR PADRÃO (garante que sempre estarão lá)
    SAN_ARRAY+=("DNS:pihole.$SERVER_HOSTNAME")
    SAN_ARRAY+=("DNS:pihole.$SERVER_HOSTNAME.$DOMAIN_SUFFIX")
    SAN_ARRAY+=("DNS:ha.$SERVER_HOSTNAME")
    SAN_ARRAY+=("DNS:ha.$SERVER_HOSTNAME.$DOMAIN_SUFFIX")
    SAN_ARRAY+=("DNS:komodo.$SERVER_HOSTNAME")
    SAN_ARRAY+=("DNS:komodo.$SERVER_HOSTNAME.$DOMAIN_SUFFIX")

    if [[ "$ENABLE_WEBMIN" == "true" ]]; then
        SAN_ARRAY+=("DNS:webmin.$SERVER_HOSTNAME")
        SAN_ARRAY+=("DNS:webmin.$SERVER_HOSTNAME.$DOMAIN_SUFFIX")
    fi

    # Adicionar subdomínios EXTRA detectados do nginx.conf (se houver)
    for sub in $SUBDOMAINS; do
        if [[ ! -z "$sub" ]]; then
            SAN_ARRAY+=("DNS:${sub}.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}")
            SAN_ARRAY+=("DNS:${sub}.${SERVER_HOSTNAME}")
        fi
    done

    # Remover duplicatas do array SAN_ARRAY (pode acontecer com a mistura de padrões e extração)
    local unique_sans=""
    for san_entry in "${SAN_ARRAY[@]}"; do
        if ! grep -q -w "$san_entry" <<< "$unique_sans"; then
            unique_sans+="$san_entry "
        fi
    done
    SAN_ARRAY=($(echo "$unique_sans" | xargs)) # Atribui de volta ao array

    # Formatar para a string final do OpenSSL
    SAN_LIST=$(IFS=,; echo "${SAN_ARRAY[*]}")
    
    log_info "📋 Subject Alternative Names configurados (final para OpenSSL):"
    echo "$SAN_LIST" | tr ',' '\n' | sed 's/^ *//' | sed 's/^/   /'

    # Criar diretório de certificados temporário para trabalhar
    TEMP_CERT_DIR=$(mktemp -d)
    log_info "📂 Diretório de trabalho temporário criado: $TEMP_CERT_DIR"
    cd "$TEMP_CERT_DIR"

    # --- Gerar CHAVE PRIVADA e CERTIFICADO AUTOASSINADO ÚNICO ---
    log_info "📋 Gerando chave privada do servidor (homeserver.key)..."
    openssl genrsa -out homeserver.key 2048

    log_info "📋 Gerando certificado autoassinado (homeserver.crt) com todos os SANs..."

    # Criar arquivo de configuração para SAN
    cat > openssl.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}
O = Home Server
C = BR

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = $SAN_LIST
EOF

    # Gerar certificado autoassinado diretamente com a chave e o config
    openssl req -x509 -new -nodes -key homeserver.key -sha256 -days $CERT_DAYS -out homeserver.crt \
      -subj "/CN=${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}/O=Home Server/C=BR" \
      -config openssl.cnf -extensions v3_req

    # --- Copiar homeserver.crt para ca.crt (para importação em clientes) ---
    log_info "Copiando homeserver.crt para ca.crt (para importação nos clientes)..."
    cp homeserver.crt ca.crt

    # 3. Limpar arquivos temporários do diretório de trabalho
    log_info "Limpando arquivos intermediários..."
    rm openssl.cnf

    # 4. Configurar permissões nos arquivos temporários
    chmod 600 homeserver.key
    chmod 644 homeserver.crt ca.crt # ca.crt agora é homeserver.crt

    # 5. Criar diretório SSL do nginx no local FINAL
    log_info "📂 Criando diretório SSL final do nginx em: $NGINX_SSL_DIR"
    mkdir -p "$NGINX_SSL_DIR"
    chmod 700 "$NGINX_SSL_DIR" 

    # 6. Copiar certificados para o nginx
    log_info "📤 Movendo certificados para o diretório SSL final..."
    cp homeserver.crt homeserver.key "$NGINX_SSL_DIR/"
    cp ca.crt "$NGINX_SSL_DIR/"

    # 7. Ajustar permissões dos arquivos copiados (agora no diretório final)
    chmod 644 "$NGINX_SSL_DIR/homeserver.crt"
    chmod 600 "$NGINX_SSL_DIR/homeserver.key"
    chmod 644 "$NGINX_SSL_DIR/ca.crt"

    # 8. Limpar o diretório de trabalho temporário
    cd - > /dev/null # Volta ao diretório anterior
    rm -r "$TEMP_CERT_DIR"
    log_info "🗑️ Diretório de trabalho temporário removido: $TEMP_CERT_DIR"

    # 9. Verificar certificado gerado
    log_info "🔍 Verificando certificado gerado ($NGINX_SSL_DIR/homeserver.crt)..."
    echo -e "${GREEN}✅ Domínios incluídos no certificado:${NC}"
    openssl x509 -in "$NGINX_SSL_DIR/homeserver.crt" -noout -text | grep -A1 "Subject Alternative Name" | \
        tail -1 | tr ',' '\n' | sed 's/^ *//' | sed 's/^/   /'

    # 10. Verificar datas de expiração
    EXPIRY_DATE=$(openssl x509 -in "$NGINX_SSL_DIR/homeserver.crt" -noout -enddate | cut -d= -f2)

    echo ""
    echo -e "${GREEN}✅ Certificados gerados e movidos com sucesso!${NC}"
    echo ""
    echo "📅 Data de expiração do certificado: ${BLUE}$EXPIRY_DATE${NC}"
    echo ""
    echo -e "${GREEN}📁 Certificados finais disponíveis em: ${BLUE}$NGINX_SSL_DIR/${NC}"
    echo -e "${GREEN}⭐ O arquivo '${BLUE}ca.crt${NC}' é uma cópia de '${BLUE}homeserver.crt${NC}' e deve ser importado em seus dispositivos clientes.${NC}"
}

main "$@"

