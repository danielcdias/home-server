#!/bin/bash

# ==============================================================================
# Script para fazer backup de todos os bancos de dados de um container
# PostgreSQL, incluindo o banco de dados 'postgres'.
#
# Este script carrega as configurações de um arquivo .env localizado no
# mesmo diretório.
# ==============================================================================

# Define o caminho para o arquivo .env (procura no mesmo diretório do script)
ENV_FILE="$(dirname "$0")/.env"

if [ -f "${ENV_FILE}" ]; then
    echo "Carregando variáveis de ambiente do arquivo ${ENV_FILE}..."
    # Exporta as variáveis do .env para o ambiente de execução do script
    # Ignora linhas comentadas e vazias.
    export $(grep -v '^#' "${ENV_FILE}" | grep -v '^$' | xargs)
else
    echo "AVISO: Arquivo .env não encontrado em ${ENV_FILE}. Usando variáveis de ambiente já existentes ou valores padrão."
fi

# Nome ou ID do container Docker onde o PostgreSQL está rodando.
readonly POSTGRES_CONTAINER_NAME="${POSTGRES_CONTAINER_NAME:-postgres}"

# Usuário do PostgreSQL com permissões para acessar todos os bancos de dados.
# O usuário 'postgres' geralmente é a escolha padrão e mais segura.
readonly POSTGRES_USER="${POSTGRES_USER:-postgres}"

# Diretório no HOST (fora do container) onde os arquivos de backup serão salvos.
# Este diretório será criado se não existir.
readonly BACKUP_DIR="/var/backups/pg_container"

echo "--- Iniciando processo de backup do PostgreSQL ---"
echo "Data e Hora: $(date +'%Y-%m-%d %H:%M:%S')"
echo "Container: ${CONTAINER_NAME}"
echo "Usuário PG: ${POSTGRES_USER}"

# 1. Verificar se o Docker está em execução
if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
    echo "[ERRO] O serviço do Docker não está em execução ou não foi encontrado."
    exit 1
fi

# 2. Garantir que o diretório de backup exista no host
echo "Verificando o diretório de backup: ${BACKUP_DIR}"
if ! mkdir -p "${BACKUP_DIR}"; then
    echo "[ERRO] Falha ao criar o diretório de backup. Verifique as permissões."
    exit 1
fi
echo "Diretório de backup garantido."

# 3. Obter a lista de todos os bancos de dados do container
# Este comando SQL exclui os bancos de dados de template, que não precisam de backup.
echo "Obtendo a lista de bancos de dados do container '${CONTAINER_NAME}'..."
DB_LIST=$(docker exec "${CONTAINER_NAME}" psql -U "${POSTGRES_USER}" -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false;")

# Verificar se a lista de bancos foi obtida com sucesso
if [ -z "${DB_LIST}" ]; then
  echo "[ERRO] Não foi possível obter a lista de bancos de dados. Verifique o nome do container, o usuário e se o container está em execução."
  exit 1
fi

echo "Bancos de dados a serem backupeados:"
echo "${DB_LIST}"
echo "----------------------------------------"

# 4. Iterar sobre cada banco de dados e executar o backup
for DB_NAME in $DB_LIST; do
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  # Remove caracteres inválidos que possam existir no nome do banco de dados para o nome do arquivo.
  CLEAN_DB_NAME=$(echo "${DB_NAME}" | tr -d '\r')
  FILE_PATH="${BACKUP_DIR}/${CLEAN_DB_NAME}-${TIMESTAMP}.sql.gz"

  echo "Iniciando backup do banco de dados '${CLEAN_DB_NAME}' para '${FILE_PATH}'..."

  # Executa o pg_dump dentro do container e canaliza (pipe) a saída para o gzip no host.
  # A saída do gzip é então redirecionada para o arquivo de backup no host.
  docker exec "${CONTAINER_NAME}" pg_dump -U "${POSTGRES_USER}" -d "${CLEAN_DB_NAME}" | gzip > "${FILE_PATH}"

  # Verifica o status de saída do comando pg_dump (o primeiro comando no pipe).
  # ${PIPESTATUS[0]} é uma variável especial do Bash que contém o código de saída do primeiro comando em um pipe.
  if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "[SUCESSO] Backup do banco de dados '${CLEAN_DB_NAME}' concluído com sucesso."
  else
    echo "[FALHA] Ocorreu um erro durante o backup do banco de dados '${CLEAN_DB_NAME}'. Removendo arquivo parcial."
    # Remove o arquivo de backup que pode ter sido criado parcialmente.
    rm -f "${FILE_PATH}"
    exit 1
  fi
  echo "----------------------------------------"
done

echo "--- Processo de backup finalizado. ---"
