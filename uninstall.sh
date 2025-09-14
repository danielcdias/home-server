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
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- 1. VERIFICAÇÃO DE PERMISSÕES SÓ PARA ROOT ---
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_error "Este script precisa ser executado como root. Use 'sudo ./uninstall.sh'."
    fi
}
# Chama a verificação de root imediatamente
check_root

# --- 2. VERIFICAÇÃO DE DIRETÓRIO E ARQUIVO uninstall.info ---
# O desinstalador DEVE ser executado da pasta de instalação.
check_uninstall_dir() {
    local current_dir="$(pwd)"
    local uninstall_info_file="$current_dir/uninstall.info"

    if [[ ! -f "$uninstall_info_file" ]]; then
        log_error "O arquivo '${BLUE}uninstall.info${NC}' não foi encontrado neste diretório."
        log_error "Este script DEVE ser executado da pasta de instalação do Home Server (onde o 'uninstall.info' está)."
        log_error "Por favor, navegue até a pasta de instalação (ex: /opt/home-server) e execute o script novamente: ${YELLOW}sudo ./uninstall.sh${NC}"
    fi

    # Carrega as variáveis do uninstall.info
    source "$uninstall_info_file"
    
    # Verifica se INSTALL_DIR foi carregado e se corresponde ao diretório atual
    if [[ -z "$INSTALL_DIR" || "$INSTALL_DIR" != "$current_dir" ]]; then
        log_error "O diretório atual '${BLUE}$current_dir${NC}' não corresponde ao INSTALL_DIR registrado em 'uninstall.info' ('${BLUE}$INSTALL_DIR${NC}')."
        log_error "Por favor, navegue até a pasta de instalação correta e execute o script novamente: ${YELLOW}sudo ./uninstall.sh${NC}"
    fi

    log_info "Confirmado: Executando desinstalador da pasta de instalação: ${BLUE}$INSTALL_DIR${NC}"
}
# Chama a verificação de diretório e carrega as variáveis imediatamente após a checagem de root.
check_uninstall_dir


# Função para pedir confirmação (apenas S/N)
confirm_action() {
    read -p "Você tem certeza que deseja continuar com a desinstalação? (S/N): " -n 1 -r REPLY_CONFIRMATION
    echo # Adiciona uma nova linha após a resposta de um único caractere
    if [[ ! "$REPLY_CONFIRMATION" =~ ^[Ss]$ ]]; then
        log_info "Operação cancelada pelo usuário."
        exit 0
    fi
}

# Função principal de desinstalação
main() {
    log_info "==============================================="
    log_info "Iniciando processo de desinstalação do Home Server"
    log_info "==============================================="

    # As variáveis INSTALL_DIR e SYSTEMD_SERVICE_NAME já foram carregadas por check_uninstall_dir
    local docker_compose_file=""

    # --- Procurar por .yml ou .yaml ---
    if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
        docker_compose_file="$INSTALL_DIR/docker-compose.yml"
        log_info "Arquivo Docker Compose encontrado: ${BLUE}docker-compose.yml${NC}"
    elif [[ -f "$INSTALL_DIR/docker-compose.yaml" ]]; then
        docker_compose_file="$INSTALL_DIR/docker-compose.yaml"
        log_info "Arquivo Docker Compose encontrado: ${BLUE}docker-compose.yaml${NC}"
    else
        log_warn "Nenhum arquivo Docker Compose (docker-compose.yml ou docker-compose.yaml) encontrado em '$INSTALL_DIR'."
    fi
    
    # --- Coletar informações para exibir ---
    local actions_list=()
    local volumes_to_remove_display=""

    actions_list+=("Serviço Systemd a ser removido: ${BLUE}'$SYSTEMD_SERVICE_NAME'${NC}")

    # --- MUDANÇA AQUI: Nova lógica de detecção de volumes ---
    if [[ -n "$docker_compose_file" && -f "$docker_compose_file" ]]; then
        local project_name=$(grep -oP '^name:\s*\K[a-zA-Z0-9_-]+' "$docker_compose_file" | head -1)
        if [[ -z "$project_name" ]]; then
            log_warn "Nome do projeto 'name:' não encontrado no Docker Compose. Usando o nome da pasta como prefixo (pode não ser preciso)."
            project_name=$(basename "$INSTALL_DIR")
        fi
        log_info "Nome do projeto Docker Compose para prefixo de volumes: ${BLUE}$project_name${NC}"

        local detected_volumes=()
        local in_volumes_block=false
        
        # Usar AWK para analisar o bloco de volumes
        # O AWK itera linha por linha.
        # - Seta 'in_volumes_block' para true quando encontra 'volumes:' sem indentação.
        # - Seta 'in_volumes_block' para false quando encontra uma linha com 0 ou 1 espaço de indentação que não seja 'volumes:'
        # - Dentro do bloco de volumes, ele pega linhas com 2 espaços de indentação e um ':' (nome do volume)
        while IFS= read -r line; do
            # Trim leading/trailing whitespace and check indentation
            local trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local leading_spaces=${#line}
            leading_spaces=$((leading_spaces - ${#trimmed_line}))

            if [[ "$in_volumes_block" == false ]]; then
                if [[ "$trimmed_line" == "volumes:" && "$leading_spaces" == 0 ]]; then
                    in_volumes_block=true
                fi
            else # Estamos no bloco de volumes
                if [[ "$leading_spaces" == 2 && "$trimmed_line" =~ ^[a-zA-Z0-9_-]+:$ ]]; then
                    local vol_name=$(echo "$trimmed_line" | sed 's/://')
                    detected_volumes+=("$vol_name")
                elif [[ "$leading_spaces" -lt 2 && "$trimmed_line" != "volumes:" ]]; then
                    # Sai do bloco de volumes se a indentação for menor que 2 e não for a própria palavra "volumes:"
                    in_volumes_block=false
                fi
            fi
        done < "$docker_compose_file"

        # Adicionar o prefixo do projeto aos volumes detectados
        local prefixed_volumes=()
        for vol in "${detected_volumes[@]}"; do
            prefixed_volumes+=("${project_name}_${vol}")
        done

        if [[ ${#prefixed_volumes[@]} -gt 0 ]]; then
            log_info "Volumes detectados no arquivo Docker Compose:"
            for vol in "${prefixed_volumes[@]}"; do
                volumes_to_remove_display+="   - ${BLUE}$vol${NC}\n"
            done
            actions_list+=("Volumes Docker nomeados a serem excluídos:\n$volumes_to_remove_display")
        else
            actions_list+=("Nenhum volume Docker nomeado encontrado para exclusão neste arquivo Docker Compose.")
        fi
    else
        actions_list+=("Nenhum arquivo Docker Compose válido encontrado. Não será possível remover containers/volumes Docker automaticamente.")
    fi
    # --- FIM DA MUDANÇA ---

    actions_list+=("Pasta de instalação a ser apagada: ${BLUE}'$INSTALL_DIR'${NC}")

    # --- Exibir resumo das ações ---
    echo ""
    log_info "As seguintes ações serão executadas durante a desinstalação:"
    echo "-----------------------------------------------------------"
    for action in "${actions_list[@]}"; do
        echo -e "${GREEN}- $action${NC}"
    done
    echo "-----------------------------------------------------------"
    echo ""

    # --- Mensagem de aviso em vermelho ---
    echo -e "${RED}======================================================================================${NC}"
    echo -e "${RED}!!! A T E N Ç Ã O !!!${NC}"
    echo -e "${RED}A exclusão dos volumes Docker CAUSARÁ a PERDA IRREVERSÍVEL de TODOS os dados de banco de dados${NC}"
    echo -e "${RED}e quaisquer outras informações persistentes dos containers.${NC}"
    echo -e "${RED}A remoção da pasta de instalação também APAGARÁ TODAS as configurações, logs e arquivos do projeto.${NC}"
    echo -e "${RED}Esses dados NÃO PODERÃO SER RECUPERADOS após a desinstalação.${NC}"
    echo -e "${RED}======================================================================================${NC}"
    echo ""

    # --- Pedir confirmação final ---
    confirm_action

    log_info "Iniciando as operações de desinstalação..."

    # 1. Parar e desabilitar o serviço systemd
    log_info "1. Parando e desabilitando o serviço systemd '$SYSTEMD_SERVICE_NAME'..."
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        systemctl stop "$SYSTEMD_SERVICE_NAME"
        log_info "Serviço parado."
    else
        log_warn "Serviço '$SYSTEMD_SERVICE_NAME' não está ativo."
    fi
    if systemctl is-enabled --quiet "$SYSTEMD_SERVICE_NAME"; then
        systemctl disable "$SYSTEMD_SERVICE_NAME"
        log_info "Serviço desabilitado."
    else
        log_warn "Serviço '$SYSTEMD_SERVICE_NAME' não está habilitado."
    fi
    rm -f "/etc/systemd/system/$SYSTEMD_SERVICE_NAME"
    systemctl daemon-reload
    log_info "Serviço systemd removido."

    # 2. Parar e remover containers Docker e volumes
    if [[ -n "$docker_compose_file" && -f "$docker_compose_file" ]]; then # Verifica se o arquivo foi encontrado para execução
        log_info "2. Parando e removendo containers e redes Docker definidos em '$docker_compose_file'..."
        pushd "$INSTALL_DIR" > /dev/null # Entra na pasta do projeto
        docker compose --file "$docker_compose_file" down
        log_info "Containers e redes removidos."

        log_info "3. Removendo volumes Docker nomeados detectados..."
        # Usamos a mesma lógica de detecção de volumes para a remoção
        local project_name_for_removal=$(grep -oP '^name:\s*\K[a-zA-Z0-9_-]+' "$docker_compose_file" | head -1)
        if [[ -z "$project_name_for_removal" ]]; then
            project_name_for_removal=$(basename "$INSTALL_DIR")
        fi

        local detected_volumes_for_removal=()
        local in_volumes_block_for_removal=false
        while IFS= read -r line; do
            local trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local leading_spaces=${#line}
            leading_spaces=$((leading_spaces - ${#trimmed_line}))

            if [[ "$in_volumes_block_for_removal" == false ]]; then
                if [[ "$trimmed_line" == "volumes:" && "$leading_spaces" == 0 ]]; then
                    in_volumes_block_for_removal=true
                fi
            else
                if [[ "$leading_spaces" == 2 && "$trimmed_line" =~ ^[a-zA-Z0-9_-]+:$ ]]; then
                    local vol_name=$(echo "$trimmed_line" | sed 's/://')
                    detected_volumes_for_removal+=("${project_name_for_removal}_${vol_name}")
                elif [[ "$leading_spaces" -lt 2 && "$trimmed_line" != "volumes:" ]]; then
                    in_volumes_block_for_removal=false
                fi
            fi
        done < "$docker_compose_file"

        if [[ ${#detected_volumes_for_removal[@]} -gt 0 ]]; then
            for vol in "${detected_volumes_for_removal[@]}"; do
                log_info "   - Removendo volume: $vol"
                docker volume rm "$vol" || log_warn "Falha ao remover volume '$vol'. Pode não existir ou estar em uso."
            done
            log_info "Volumes Docker nomeados processados."
        else
            log_info "Nenhum volume Docker nomeado encontrado para remover."
        fi
        popd > /dev/null # Sai da pasta do projeto
    else
        log_warn "Nenhum arquivo Docker Compose válido encontrado. Não foi possível remover containers/volumes Docker."
    fi

    # 4. Remover a pasta de instalação
    if [[ -d "$INSTALL_DIR" ]]; then
        log_info "4. Removendo pasta de instalação '$INSTALL_DIR'..."
        rm -rf "$INSTALL_DIR"
        log_info "Pasta de instalação removida."
    else
        log_warn "Pasta de instalação '$INSTALL_DIR' não encontrada para remover."
    fi

    log_info "==============================================="
    log_info "✅ Desinstalação concluída com sucesso!"
    log_info "==============================================="
}

main "$@"

