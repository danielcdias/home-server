#!/bin/bash

set -e

# Aguarda o banco de dados estar pronto
until pg_isready -h localhost -p 5432 -U ${POSTGRES_USER}
do
  echo "Aguardando o banco de dados..."
  sleep 2
done

echo "Banco de dados pronto. Criando bancos de dados e usuários..."

# Exporta a variável de ambiente PGPASSWORD
export PGPASSWORD=${POSTGRES_PASSWORD}

# Lê o arquivo JSON usando 'jq'
config_json=$(cat /docker-entrypoint-initdb.d/config/config.json)

# Itera sobre cada objeto JSON (cada conjunto de credenciais)
for row in $(echo "${config_json}" | jq -r '.[] | @base64'); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }

    DB_NAME=$(_jq '.db_name')
    DB_USER=$(_jq '.user')
    DB_PASSWORD=$(_jq '.password')

    # Verifica se o banco de dados já existe
    if ! psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
        echo "Criando banco de dados: $DB_NAME"
        psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE DATABASE \"$DB_NAME\";"
        
        echo "Criando usuário: $DB_USER"
        psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"

        echo "Concedendo privilégios em $DB_NAME para $DB_USER"
        psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"
    else
        echo "Banco de dados '$DB_NAME' já existe. Ignorando a criação."
    fi
done

echo "Configuração inicial do banco de dados concluída."

# Limpa a variável PGPASSWORD para não expor a senha
unset PGPASSWORD
