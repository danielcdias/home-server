#!/bin/bash

# Define a lista de arquivos e suas prioridades
declare -a docker_compose_files

echo "Buscando por arquivos 'docker-compose.yml' com arquivos de prioridade 'prio.txt'..."

# Encontra todas as subpastas
find . -type d -mindepth 1 | while read -r dir; do
    # Verifica se a subpasta contém um arquivo de prioridade e um arquivo docker-compose
    if [[ -f "${dir}/prio.txt" && -f "${dir}/docker-compose.yml" ]]; then
        priority=$(head -n 1 "${dir}/prio.txt" | tr -d ' ' | tr -d '\n')
        
        # Valida se a prioridade é um número entre 0 e 100
        if [[ "$priority" =~ ^[0-9]+$ ]] && (( priority >= 0 && priority <= 100 )); then
            # Adiciona a prioridade e o caminho do arquivo à lista
            docker_compose_files+=("${priority}:${dir}/docker-compose.yml")
            echo "  - Encontrado: ${dir}/docker-compose.yml (Prioridade: ${priority})"
        else
            echo "  - AVISO: O arquivo de prioridade em '${dir}' não contém um número válido (0-100). Ignorando esta pasta."
        fi
    fi
done

# Verifica se algum arquivo foi encontrado
if [ ${#docker_compose_files[@]} -eq 0 ]; then
    echo "Nenhum arquivo 'docker-compose.yml' com 'prio.txt' encontrado. Encerrando."
    exit 1
fi

# Ordena os arquivos pela prioridade numérica (0 a 100)
IFS=$'\n' sorted_files=($(sort -n -t: -k1 <<<"${docker_compose_files[*]}"))
unset IFS

# Constrói o comando docker-compose com os arquivos ordenados
command="docker-compose"
for item in "${sorted_files[@]}"; do
    file_path=$(echo "$item" | cut -d: -f2)
    command+=" -f ${file_path}"
done

command+=" up -d"

# Exibe o comando final e o executa
echo "---"
echo "Comando a ser executado:"
echo "$command"
echo "---"

eval "$command"

echo "Deploy concluído!"
