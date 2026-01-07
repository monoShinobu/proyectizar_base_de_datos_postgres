#!/bin/bash

source "$(dirname "$0")/config_env.sh"

DB_NAME=${PGDB_NAME:-$DB_NAME}


echo "📊 Extracción de tablas en proceso"
cd ..
./extraction/table_extraction.sh
./extraction/functions_extraction.sh


#echo "Script hijo terminó, continuando con el principal"
