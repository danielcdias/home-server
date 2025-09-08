#!/bin/bash

# Configurações padrão
DEFAULT_PROJECT_DIR="/home/daniel/home-server"
SERVER_IP="10.1.1.2"
SERVER_HOSTNAME="homeserver"
DOMAIN_SUFFIX="lan"
CA_DAYS=18250
SERVER_DAYS=1825

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 [--path CAMINHO_DO_PROJETO]"
    echo "  --path CAMINHO_DO_PROJETO  Diretório do projeto (padrão: $DEFAULT_PROJECT_DIR)"
    exit 1
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
                echo -e "${RED}Argumento desconhecido: $1${NC}"
                show_usage
                ;;
        esac
    done
    
    NGINX_SSL_DIR="$PROJECT_DIR/nginx/ssl"
    NGINX_CONF_FILE="$PROJECT_DIR/nginx/reverse-proxy.conf"
}

# Função para extrair subdomínios do nginx CORRETAMENTE
extract_subdomains() {
    echo -e "${GREEN}🔍 Analisando configuração do nginx...${NC}"
    
    if [[ ! -f "$NGINX_CONF_FILE" ]]; then
        echo -e "${RED}❌ Arquivo de configuração do nginx não encontrado: $NGINX_CONF_FILE${NC}"
        exit 1
    fi
    
    # Extrair TODOS os server_name, filtrando apenas os que contêm ponto (subdomínios)
    SUBDOMAINS=$(grep -oP 'server_name\s+\K[^;]+' "$NGINX_CONF_FILE" | \
                 tr ' ' '\n' | \
                 grep -v "^$" | \
                 grep -v "^\s*$" | \
                 grep -v "^${SERVER_HOSTNAME}$" | \
                 grep -v "^${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}$" | \
                 grep -v "^~" | \
                 grep "\\." | \
                 sed "s/\\.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}//" | \
                 sed "s/\\.${SERVER_HOSTNAME}//" | \
                 sort | uniq)
    
    # Remover entradas vazias ou inválidas
    SUBDOMAINS=$(echo "$SUBDOMAINS" | grep -v "^\s*$" | grep -v "^${SERVER_HOSTNAME}" | grep -v "^localhost$")
    
    if [[ -z "$SUBDOMAINS" ]]; then
        echo -e "${RED}❌ ERRO: Nenhum subdomínio encontrado na configuração do nginx${NC}"
        echo -e "${YELLOW}📋 Verifique o arquivo: $NGINX_CONF_FILE${NC}"
        echo -e "${YELLOW}📋 Conteúdo encontrado:${NC}"
        grep -oP 'server_name\s+\K[^;]+' "$NGINX_CONF_FILE" | tr ' ' '\n'
        exit 1
    fi
    
    echo -e "${GREEN}✅ Subdomínios detectados:${NC}"
    echo "$SUBDOMAINS" | while read sub; do
        if [[ ! -z "$sub" ]]; then
            echo "   - $sub.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}"
            echo "   - $sub.${SERVER_HOSTNAME}"  # Sem .lan também
        fi
    done
}

# Função principal
main() {
    parse_arguments "$@"
    
    echo -e "${GREEN}🔐 Iniciando geração de certificados...${NC}"
    echo -e "${GREEN}📅 Validade: 5 ANOS${NC}"
    echo -e "${YELLOW}📝 IP do servidor: $SERVER_IP${NC}"
    echo -e "${YELLOW}📝 Hostname: $SERVER_HOSTNAME${NC}"
    echo -e "${YELLOW}📝 Domínio: $DOMAIN_SUFFIX${NC}"
    echo -e "${YELLOW}📁 Diretório do projeto: $PROJECT_DIR${NC}"
    echo ""

    # Extrair subdomínios automaticamente
    extract_subdomains

    # Criar lista de Subject Alternative Names (SAN)
    SAN="DNS:${SERVER_HOSTNAME}, DNS:${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}, DNS:localhost, IP:${SERVER_IP}"

    # Adicionar todos os subdomínios detectados (COM e SEM .lan)
    for sub in $SUBDOMAINS; do
        if [[ ! -z "$sub" ]]; then
            # Com sufixo .lan
            SAN="$SAN, DNS:${sub}.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX}"
            # Sem sufixo .lan
            SAN="$SAN, DNS:${sub}.${SERVER_HOSTNAME}"
        fi
    done

    echo -e "${GREEN}📋 Subject Alternative Names configurados:${NC}"
    echo "$SAN" | tr ',' '\n' | sed 's/^ //' | sed 's/^/   /'

    # Criar diretório de certificados temporário
    mkdir -p ~/certs && cd ~/certs
    echo "📂 Diretório temporário criado: ~/certs"

    # 1. Criar Autoridade Certificadora (CA)
    echo "📋 Criando Autoridade Certificadora..."
    openssl genrsa -out ca.key 2048
    openssl req -x509 -new -nodes -key ca.key -sha256 -days $CA_DAYS -out ca.crt \
      -subj "/CN=HomeServer Local CA/O=Home Network/C=BR"

    # 2. Criar certificado do servidor
    echo "📋 Criando certificado do servidor..."
    openssl genrsa -out homeserver.key 2048

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
subjectAltName = $SAN
EOF

    # Gerar CSR com SAN
    openssl req -new -key homeserver.key -out homeserver.csr -config openssl.cnf

    # Assinar certificado com SAN
    openssl x509 -req -in homeserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
      -out homeserver.crt -days $SERVER_DAYS -sha256 -extensions v3_req -extfile openssl.cnf

    # 3. Limpar arquivos temporários
    rm homeserver.csr openssl.cnf

    # 4. Configurar permissões
    chmod 600 ca.key homeserver.key
    chmod 644 ca.crt homeserver.crt

    # 5. Criar diretório SSL do nginx
    echo "📂 Criando diretório SSL do nginx..."
    mkdir -p "$NGINX_SSL_DIR"
    chmod 755 "$NGINX_SSL_DIR"

    # 6. Copiar certificados para o nginx
    echo "📤 Movendo certificados para o nginx..."
    cp homeserver.crt homeserver.key "$NGINX_SSL_DIR/"
    cp ca.crt "$NGINX_SSL_DIR/"

    # 7. Ajustar permissões dos arquivos copiados
    chmod 644 "$NGINX_SSL_DIR/homeserver.crt"
    chmod 600 "$NGINX_SSL_DIR/homeserver.key"
    chmod 644 "$NGINX_SSL_DIR/ca.crt"

    # 8. Ajustar ownership para o usuário daniel
    if [[ $EUID -eq 0 ]]; then
        chown -R daniel:daniel "$NGINX_SSL_DIR"
        echo "👤 Permissões ajustadas para usuário daniel"
    fi

    # 9. Verificar certificado gerado
    echo "🔍 Verificando certificado gerado..."
    echo -e "${GREEN}✅ Domínios incluídos no certificado:${NC}"
    openssl x509 -in homeserver.crt -noout -text | grep -A1 "Subject Alternative Name" | \
        tail -1 | tr ',' '\n' | sed 's/^ *//' | sed 's/^/   /'

    # 10. Verificar datas de expiração
    CA_EXPIRY=$(openssl x509 -in ca.crt -noout -enddate | cut -d= -f2)
    SERVER_EXPIRY=$(openssl x509 -in homeserver.crt -noout -enddate | cut -d= -f2)

    echo ""
    echo -e "${GREEN}✅ Certificados gerados e movidos com sucesso!${NC}"
    echo ""
    echo "📅 Datas de expiração:"
    echo "   - CA: $CA_EXPIRY"
    echo "   - Servidor: $SERVER_EXPIRY"
    echo ""
    echo -e "${GREEN}📁 Certificados disponíveis em: $NGINX_SSL_DIR/${NC}"
}

main "$@"
