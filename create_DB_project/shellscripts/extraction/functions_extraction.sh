#!/bin/bash

source "$(dirname "$-1")/config/config_env.sh"

# Usar variables de Bitbucket Pipelines si están disponibles
DB_USER=${PGUSER:-$DB_USER}
DB_PASSWORD=${PGPASSWORD:-$DB_PASSWORD}
DB_HOST=${PGHOST:-$DB_HOST}
DB_PORT=${PGPORT:-$DB_PORT}

DB_NAME=${PGDB_NAME:-$DB_NAME}
DB_SCHEMA=${PGSCHEMA:-$DB_SCHEMA}

echo -e "ℹ️ Usando conexión: host=$DB_HOST port=$DB_PORT user=$DB_USER db=$DB_NAME\n"

#Acá comienza el código
FUNCTIONS_NAME=$(PGPASSWORD="$DB_PASSWORD" "$PSQL_PATH" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -At -c "-- Obtiene todas las funciones de la BD
        SELECT
            n.nspname AS schema_name,
            p.proname AS function_name
        FROM
            pg_proc p
        JOIN
            pg_namespace n ON n.oid = p.pronamespace
        WHERE
            n.nspname NOT IN ('pg_catalog', 'information_schema')
        GROUP BY 
          function_name, schema_name
        ORDER BY
            schema_name, function_name;"
)

echo -e "$FUNCTIONS_NAME\n"


FUNCTIONS_PATH="../projects/$DB_NAME/components/functions" 
mkdir -p "$FUNCTIONS_PATH"

for function in $FUNCTIONS_NAME; do
    IFS="|" read -ra FUNC_NAMES <<< "$function"
    FUNC_NAME=$(echo "${FUNC_NAMES[1]}" | xargs) 
    
    echo -e "FUNC_NAME = $FUNC_NAME"

    FUNCTIONS_STRUCTURE=$(PGPASSWORD="$DB_PASSWORD" "$PSQL_PATH" \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        -At -c "-- Obtiene todas las estructuras de las funciones de la BD
            SELECT --n.nspname AS schema_name
                --, p.proname AS function_name
                 pg_get_functiondef(p.oid)        AS func_def
                --, pg_get_function_arguments(p.oid) AS func_args
                --, pg_get_function_result(p.oid)    AS func_result
            FROM   pg_proc p
            JOIN   pg_namespace n ON n.oid = p.pronamespace
            WHERE  p.proname = '${FUNC_NAME}';"
    )

    printf "%s\n " "$FUNCTIONS_STRUCTURE" | tr -d '\r' | sed -e '/^\$function\$$/ { N; s/\$function\$\n/\$function\$\n;\n/ }' > "$FUNCTIONS_PATH/$FUNC_NAME.sql"
done

shopt -u nullglob  # buena practica: dejar la shell como estaba