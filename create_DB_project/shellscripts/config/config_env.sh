#!/bin/bash


#0 indica que estamos en bitbucket
EXEC_ENV=0

# Detectar la ubicación de psql
if [ -d "/opt/atlassian/pipelines" ]; then
  # Estamos en Bitbucket Pipelines
  PSQL_PATH="${PSQL_COMMAND}"
  echo "📌 Ambiente detectado: Bitbucket Pipelines"
else
  #1 indica que estamos en local
  EXEC_ENV=1
  # Intentar encontrar psql en ubicaciones comunes
  if [ -x "/c/Program Files/PostgreSQL/17/bin/${PSQL_COMMAND}" ]; then
    PSQL_PATH="/c/Program Files/PostgreSQL/17/bin/${PSQL_COMMAND}"
  elif [ -x "/c/Program Files/PostgreSQL/16/bin/${PSQL_COMMAND}" ]; then
    PSQL_PATH="/c/Program Files/PostgreSQL/16/bin/${PSQL_COMMAND}"
  elif [ -x "/c/Program Files/PostgreSQL/15/bin/${PSQL_COMMAND}" ]; then
    PSQL_PATH="/c/Program Files/PostgreSQL/15/bin/${PSQL_COMMAND}"
  elif command -v "${PSQL_COMMAND}" >/dev/null 2>&1; then
    PSQL_PATH="${PSQL_COMMAND}"
  else
    echo "❌ Error: No se pudo encontrar psql. Por favor, instala PostgreSQL o proporciona la ruta manualmente."
    exit 1
  fi
  echo "📌 Ambiente detectado: Local (usando $PSQL_PATH)"
fi

# Determinar directorio base del proyecto
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/../.." && pwd )"

ENV_FILE="$PROJECT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  # Cargar variables del archivo .env
  set -a  # Exportar todas las variables automáticamente
  source "$ENV_FILE"
  set +a
  echo "✅ Configuración de ambiente cargada"
else
  echo "❌ Error: No se encuentra el archivo de ambiente $ENV_FILE."
  exit 1
fi