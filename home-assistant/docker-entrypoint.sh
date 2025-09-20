#!/bin/bash

HACS_DIR="/config/custom_components/hacs"
HA_UID=1000 # ID do usuário do Home Assistant
HA_GID=1000 # ID do grupo do Home Assistant

# Verifica se o HACS não está instalado
if [ ! -d "$HACS_DIR" ]; then
  echo "HACS não encontrado. Iniciando instalação direta..."

  if ! command -v unzip &> /dev/null; then
    echo "'unzip' não encontrado. Instalando..."
    apk add --no-cache unzip
  fi

  mkdir -p /config/custom_components

  echo "Baixando HACS (hacs.zip)..."
  wget -q -O /config/custom_components/hacs.zip https://github.com/hacs/integration/releases/latest/download/hacs.zip

  echo "Descompactando HACS..."
  unzip -q /config/custom_components/hacs.zip -d "$HACS_DIR"

  rm /config/custom_components/hacs.zip

  echo "Ajustando permissões para UID:GID ${HA_UID}:${HA_GID}..."
  chown -R ${HA_UID}:${HA_GID} /config/custom_components

  if [ -f "$HACS_DIR/manifest.json" ]; then
    echo "SUCESSO: HACS instalado e permissões ajustadas."
  else
    echo "FALHA: Instalação direta do HACS não foi concluída."
  fi
else
  echo "HACS já está instalado. Nenhuma ação necessária."
fi

echo "Iniciando o Home Assistant..."
exec /init
