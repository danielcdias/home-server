#!/bin/bash

# Diretório de destino do HACS
HACS_DIR="/config/custom_components/hacs"

# Função para instalar o HACS
install_hacs() {
  echo "HACS não encontrado. Iniciando a instalação..."
  
  # Baixa e executa o script de instalação do HACS
  wget -q -O - https://get.hacs.xyz | bash -

  if [ $? -eq 0 ]; then
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

# Inicia o serviço principal do Home Assistant
# O comando `exec` garante que o processo principal do container seja o Home Assistant
echo "Iniciando o Home Assistant..."
exec /usr/bin/python3 -m homeassistant --config /config "$@"
