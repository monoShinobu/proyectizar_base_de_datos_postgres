#!/bin/bash

PSQL_COMMAND="psql"

source "$(dirname "$-1")/config/config_env.sh"

#Definimos otros comando psql
PSQL_PATH_DUMP_COMMAND=$(echo "$PSQL_PATH" | sed 's|psql|pg_dump|')

# Usar variables de Bitbucket Pipelines si están disponibles
DB_USER=${PGUSER:-$DB_USER}
DB_PASSWORD=${PGPASSWORD:-$DB_PASSWORD}
DB_HOST=${PGHOST:-$DB_HOST}
DB_PORT=${PGPORT:-$DB_PORT}

DB_NAME=${PGDB_NAME:-$DB_NAME}
DB_SCHEMA=${PGSCHEMA:-$DB_SCHEMA}

echo "ℹ️ Usando conexión: host=$DB_HOST port=$DB_PORT user=$DB_USER db=$DB_NAME"

#Acá comienza el código
TABLES=$(PGPASSWORD="$DB_PASSWORD" "$PSQL_PATH" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -t -c "-- Obtiene todas las tablas de la bd
        SELECT table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND table_schema NOT IN ('pg_catalog', 'information_schema')
        ORDER BY table_schema,
                 table_name;"
)


shopt -u nullglob  # buena practica: dejar la shell como estaba