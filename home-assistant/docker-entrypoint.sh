#!/bin/bash

# Diretório de configuração do Home Assistant
CONFIG_DIR="/config"
# Diretório de destino do HACS
HACS_DIR="${CONFIG_DIR}/custom_components/hacs"

# Função para instalar o HACS de forma mais robusta
install_hacs() {
  echo "HACS não encontrado. Iniciando a instalação..."

  # Navega para o diretório de componentes personalizados
  mkdir -p "${HACS_DIR}"
  cd "${HACS_DIR}"

  # Baixa o arquivo zip da última versão do HACS
  # Usando uma URL fixa para o zip, que é mais confiável que o pip
  wget -q -O hacs.zip "https://github.com/hacs/integration/archive/main.zip"

  # Descompacta o conteúdo do arquivo
  unzip -q hacs.zip

  # Move os arquivos para o diretório correto
  mv integration-main/* .

  # Limpa os arquivos temporários
  rm -rf integration-main hacs.zip

  # Navega de volta para o diretório de configuração
  cd "${CONFIG_DIR}"

  if [ -d "${HACS_DIR}" ]; then
    echo "Instalação do HACS concluída com sucesso."
  else
    echo "Erro na instalação do HACS."
  fi
}

# Verifica se o diretório do HACS já existe
if [ ! -d "$HACS_DIR" ]; then
    install_hacs
else
    echo "HACS já está instalado. Nenhuma ação necessária."
fi

# Cria o arquivo de configuração inicial, se ele não existir
if [ ! -f "${CONFIG_DIR}/configuration.yaml" ]; then
    echo "Criando o arquivo de configuração inicial..."
    cat <<EOF > "${CONFIG_DIR}/configuration.yaml"
# Configuração do proxy reverso para Nginx
http:
  server_host:
    - 0.0.0.0
  use_x_forwarded_for: true
  trusted_proxies:
    - 0.0.0.0/0
  login_attempts_threshold: 3
EOF
fi

# Inicia o serviço principal do Home Assistant
echo "Iniciando o Home Assistant..."
exec python3 -m homeassistant --config "${CONFIG_DIR}" "$@"
