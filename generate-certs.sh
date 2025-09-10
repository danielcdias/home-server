#!/bin/bash

# Configurações
CA_DAYS=18250
SERVER_DAYS=1825
SERVER_IP="10.1.1.2" # Você pode querer tornar isso um argumento também

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Função para log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 --path CAMINHO --hostname NOME --domain-suffix SUFIXO [--webmin true|false]"
    exit 1
}

# Função para parsear argumentos
parse_arguments() {
    # Definir padrões
    PROJECT_DIR=""
    SERVER_HOSTNAME=""
    DOMAIN_SUFFIX=""
    ENABLE_WEBMIN=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --path) PROJECT_DIR="$2"; shift 2 ;;
            --hostname) SERVER_HOSTNAME="$2"; shift 2 ;;
            --domain-suffix) DOMAIN_SUFFIX="$2"; shift 2 ;;
            --webmin) [[ "$2" == "true" ]] && ENABLE_WEBMIN=true || ENABLE_WEBMIN=false; shift 2 ;;
            --help|-h) show_usage ;;
            *) echo -e "${RED}Argumento desconhecido: $1${NC}"; show_usage ;;
        esac
    done

    if [[ -z "$PROJECT_DIR" || -z "$SERVER_HOSTNAME" || -z "$DOMAIN_SUFFIX" ]]; then
        echo -e "${RED}Erro: --path, --hostname e --domain-suffix são obrigatórios.${NC}"
        show_usage
    fi
    
    NGINX_SSL_DIR="$PROJECT_DIR/nginx/ssl"
}

# Função principal
main() {
    parse_arguments "$@"
    
    log_info "🔐 Iniciando geração de certificados..."
    log_info "   - Hostname: $SERVER_HOSTNAME"
    log_info "   - Domínio: $DOMAIN_SUFFIX"
    log_info "   - Webmin: $ENABLE_WEBMIN"
    log_info "   - Diretório: $PROJECT_DIR"

    # Definir subdomínios estaticamente
    SUBDOMAINS="pihole ha komodo"
    if [[ "$ENABLE_WEBMIN" == true ]]; then
        SUBDOMAINS="$SUBDOMAINS webmin"
    fi

    # Criar lista de Subject Alternative Names (SAN)
    SAN="DNS:${SERVER_HOSTNAME}, DNS:${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}, DNS:localhost, IP:${SERVER_IP}"
    for sub in $SUBDOMAINS; do
        SAN="$SAN, DNS:${sub}.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}"
        SAN="$SAN, DNS:${sub}.${SERVER_HOSTNAME}"
    done

    log_info "📋 Subject Alternative Names configurados:"
    echo "$SAN" | tr ',' '\n' | sed 's/^ //' | sed 's/^/   /'

    # Criar diretório de certificados temporário
    TEMP_CERT_DIR=$(mktemp -d)
    log_info "📂 Diretório temporário criado: $TEMP_CERT_DIR"
    cd "$TEMP_CERT_DIR"

    # 1. Criar Autoridade Certificadora (CA)
    log_info "   - Criando Autoridade Certificadora (CA)..."
    openssl genrsa -out ca.key 2048 > /dev/null 2>&1
    openssl req -x509 -new -nodes -key ca.key -sha256 -days $CA_DAYS -out ca.crt \
      -subj "/CN=HomeServer Local CA/O=Home Network/C=BR" > /dev/null 2>&1

    # 2. Criar certificado do servidor
    log_info "   - Criando chave e certificado do servidor..."
    openssl genrsa -out ${SERVER_HOSTNAME}.key 2048 > /dev/null 2>&1

    # Criar arquivo de configuração para SAN
    cat > openssl.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = ${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}
[v3_req]
subjectAltName = @alt_names
[alt_names]
$(echo $SAN | sed 's/, /\\n/g' | sed 's/^/DNS.1 = /' | awk '{gsub(/DNS:/, "DNS."); print}' | nl -n rz -s " = " | sed 's/ //g')
EOF

    # Gerar CSR com SAN
    openssl req -new -key ${SERVER_HOSTNAME}.key -out ${SERVER_HOSTNAME}.csr -config openssl.cnf > /dev/null 2>&1

    # Assinar certificado com SAN
    openssl x509 -req -in ${SERVER_HOSTNAME}.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
      -out ${SERVER_HOSTNAME}.crt -days $SERVER_DAYS -sha256 -extfile openssl.cnf -extensions v3_req > /dev/null 2>&1

    # 3. Criar diretório SSL do nginx e mover arquivos
    log_info "   - Copiando certificados para $NGINX_SSL_DIR..."
    mkdir -p "$NGINX_SSL_DIR"
    
    cp ${SERVER_HOSTNAME}.crt "$NGINX_SSL_DIR/"
    cp ${SERVER_HOSTNAME}.key "$NGINX_SSL_DIR/"
    cp ca.crt "$NGINX_SSL_DIR/"

    # 4. Ajustar permissões
    chmod 644 "$NGINX_SSL_DIR/"*.crt
    chmod 600 "$NGINX_SSL_DIR/"*.key
    
    # 5. Limpar diretório temporário
    rm -rf "$TEMP_CERT_DIR"

    log_info "✅ Certificados gerados com sucesso!"
    echo -e "${GREEN}📅 Validade do certificado do servidor: $(openssl x509 -in $NGINX_SSL_DIR/${SERVER_HOSTNAME}.crt -noout -enddate)${NC}"
}

main "$@"
