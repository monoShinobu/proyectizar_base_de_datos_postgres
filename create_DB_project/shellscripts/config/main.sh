#!/bin/bash

source "$(dirname "$0")/config_env.sh"

DB_NAME=${PGDB_NAME:-$DB_NAME}

#Creamos la carpeta del proyecto
mkdir -p "../projects/$DB_NAME" 

echo "📊 Extracción de tablas en proceso"

./table_extraction.sh


echo "Script hijo terminó, continuando con el principal"
