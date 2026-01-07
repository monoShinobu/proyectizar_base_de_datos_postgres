#!/bin/bash

source "$(dirname "$-1")/config/config_env.sh"
source "$(dirname "$-1")/extraction/util/type_convertion.sh"


#Definimos otros comando psql
PSQL_PATH_DUMP_COMMAND=$(echo "$PSQL_PATH" | sed 's|psql|pg_dump|')

# Usar variables de Bitbucket Pipelines si están disponibles
DB_USER=${PGUSER:-$DB_USER}
DB_PASSWORD=${PGPASSWORD:-$DB_PASSWORD}
DB_HOST=${PGHOST:-$DB_HOST}
DB_PORT=${PGPORT:-$DB_PORT}

DB_NAME=${PGDB_NAME:-$DB_NAME}
DB_SCHEMA=${PGSCHEMA:-$DB_SCHEMA}

echo -e "ℹ️ Usando conexión: host=$DB_HOST port=$DB_PORT user=$DB_USER db=$DB_NAME\n"

#Acá comienza el código

#Agregar a futuro que sea multi schema
SCHEMA="public"

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

#Crear carpeta de los componentes de las tablas
TABLES_PATH="../projects/$DB_NAME/components/tables" 
mkdir -p "$TABLES_PATH"

for table in $TABLES; do
    #Creación del archivo para la tabla
    TABLENAME=$(echo "$table" | tr -d '\r\n' )
    touch "$TABLES_PATH/$TABLENAME.sql"
    echo "" > "$TABLES_PATH/$TABLENAME.sql"

    #Escritura del script para crear la tabla en BD
    #Usando PG_dump
<<COMMENT
    PGPASSWORD="$DB_PASSWORD" "$PSQL_PATH_DUMP_COMMAND" \
                    -h "$DB_HOST" \
                    -p "$DB_PORT" \
                    -U "$DB_USER" \
                    -d "$DB_NAME" \
                    -t "$TABLENAME" --schema-only --no-owner \
    | grep -vE '^(SET|SELECT pg_catalog.set_config)' > "$TABLES_PATH/$TABLENAME.sql"
COMMENT

    #Escritura de DDL de tabla manual
    TABLE_COMPOSITION=$(PGPASSWORD="$DB_PASSWORD" "$PSQL_PATH" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -t -c "SELECT column_name,       --[0] Nombre de la columna
          udt_name,                  --[1] Tipo de dato
          character_maximum_length,  --[2] Si es texto, obtenemos el largo
          --
          --identity config          <-Identity
          is_identity,               --[3]
          identity_generation,       --[4]
          identity_start,            --[5]
          identity_increment,        --[6]
          identity_maximum,          --[7]
          identity_minimum,          --[8]
          --
          column_default,            --[9] Valor por defecto
          --
          --collation                 <-Collation
          collation_name,            --[10]
          --
          is_nullable                --[11]
          FROM information_schema.columns
          WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
          AND table_name = '$TABLENAME';"
        )

      echo "CREATE TABLE $SCHEMA.$TABLENAME (" >> "$TABLES_PATH/$TABLENAME.sql"

      #################################################
      ##############    DDL COLUMNAS    ###############
      #################################################
      while IFS= read -r fila; do
        #Separamos la fila en datos
        IFS="|" read -ra COL_PARAMS <<< "$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<< "$fila")"

        #Agregamos el nombre de la columna y el tipo de dato
        COL_CONFIG="$(echo "${COL_PARAMS[0]}" | xargs) $(echo "${COL_PARAMS[1]}" | xargs)"

        #En caso de ser texto, agregamos su tamaño
        if [ "$(echo "${COL_PARAMS[2]}" | xargs)" != "" ]; then
          #Quitamos los espacios del tamaño del char
          COL_CONFIG="${COL_CONFIG}($(echo "${COL_PARAMS[2]}" | xargs))"
        fi

        #Vemos si tiene identity
        if [ "$(echo "${COL_PARAMS[3]}" | xargs)" = "YES" ]; then
          #Hay que ver el ciclo a futuro
          COL_CONFIG="${COL_CONFIG} GENERATED $(echo "${COL_PARAMS[4]}" | xargs) "\
"AS IDENTITY( "\
"INCREMENT BY $(echo "${COL_PARAMS[6]}" | xargs) "\
"MINVALUE $(echo "${COL_PARAMS[8]}" | xargs) "\
"MAXVALUE $(echo "${COL_PARAMS[7]}" | xargs) "\
"START $(echo "${COL_PARAMS[5]}" | xargs)"\
"1 CACHE 1 NO CYCLE"\
")"
        fi

        #Vemos si tiene VALOR POR DEFECTO
        if [ "$(echo "${COL_PARAMS[9]}" | xargs)" != "" ]; then
          COL_CONFIG="${COL_CONFIG} DEFAULT $(awk '{$1=$1}1' <<< "${COL_PARAMS[9]}")"
        fi

        #Vemos si tiene COLLATION
        if [ "$(echo "${COL_PARAMS[10]}" | xargs)" != "" ]; then
          COL_CONFIG="${COL_CONFIG} COLLATE \"$(echo "${COL_PARAMS[10]}" | xargs)\""
        fi

        #Vemos si es NOT NULL
        if [ "$(echo "${COL_PARAMS[11]}" | xargs)" = "NO" ]; then
          COL_CONFIG="${COL_CONFIG} NOT NULL"
        fi

        echo "	$COL_CONFIG," >> "$TABLES_PATH/$TABLENAME.sql"
      done <<< "$TABLE_COMPOSITION"


      #################################################
      ###########    Constraints tabla    #############
      #################################################
      CONSTRAINTS_COMPOSITION=$(PGPASSWORD="$DB_PASSWORD" "$PSQL_PATH" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -t -c "SELECT 
          con.contype,           --[0] Tipo de constraint
          con.conname,           --[1] Nombre de la constraint
          kcu.COLUMN_NAME,       --[2] Nombre de la columna
          ccu.table_name,        --[3] Nombre de la tabla referenciada
          ccu.column_name,       --[4] Nombre de la columna referenciada
          con.confdeltype,       --[5] Tipo de eliminacion de referencia
          con.confupdtype        --[6] Tipo de actualizacion de referencia
          FROM pg_catalog.pg_constraint con
          INNER JOIN pg_catalog.pg_class rel ON rel.oid = con.conrelid
          INNER JOIN pg_catalog.pg_namespace nsp ON nsp.oid = connamespace
          JOIN information_schema.key_column_usage kcu ON kcu.constraint_name = con.conname
          LEFT JOIN information_schema.constraint_column_usage ccu ON con.conname = ccu.CONSTRAINT_NAME 
          WHERE nsp.nspname = '$SCHEMA'
          AND rel.relname = '$TABLENAME';"
        )

        while IFS=  read -r filaConstraint; do
          #Separamos la fila en datos
          IFS="|" read -ra CONS_PARAMS <<< "$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<< "$filaConstraint")"

          #Verificamos si es constraint de llave PRIMARIA
          if [ "$(echo "${CONS_PARAMS[0]}" | xargs)" = "p" ]; then
            CONST_CONFIG="CONSTRAINT $(echo "${CONS_PARAMS[1]}" | xargs) PRIMARY KEY ($(echo "${CONS_PARAMS[2]}" | xargs)),"
            echo "    $CONST_CONFIG" >> "$TABLES_PATH/$TABLENAME.sql"
          fi

          #Verificamos si es constraint de llave FORANEA
          if [ "$(echo "${CONS_PARAMS[0]}" | xargs)" = "f" ]; then
            CONST_CONFIG="CONSTRAINT $(echo "${CONS_PARAMS[1]}" | xargs) "\
"FOREIGN KEY ($(echo "${CONS_PARAMS[2]}" | xargs)) "\
"REFERENCES ${SCHEMA}.$(echo "${CONS_PARAMS[3]}" | xargs)($(echo "${CONS_PARAMS[4]}" | xargs))"
          
            #Validacion si existen reglas de eliminacion
            if [ "$(echo "${CONS_PARAMS[5]}" | xargs )" != "" ]; then
              ACTION_TYPE="${CONS_PARAMS[5]}"
              CONST_CONFIG="${CONST_CONFIG} ON DELETE $(table_actions $ACTION_TYPE)"
            fi

            #Validacion si existen reglas de actualización
            if [ "$(echo "${CONS_PARAMS[6]}" | xargs )" != "" ]; then
              ACTION_TYPE="${CONS_PARAMS[6]}"
              CONST_CONFIG="${CONST_CONFIG} ON UPDATE $(table_actions $ACTION_TYPE)"
            fi

            echo -n "    $CONST_CONFIG," >> "$TABLES_PATH/$TABLENAME.sql"
          fi

        done <<< "$CONSTRAINTS_COMPOSITION"
      
      sed -i '$s/,//' "$TABLES_PATH/$TABLENAME.sql"
      echo -e "\n);" >> "$TABLES_PATH/$TABLENAME.sql"


      #################################################
      ##############    Comentarios    ################
      #################################################
      COMMENTS_COMPOSITION=$(PGPASSWORD="$DB_PASSWORD" "$PSQL_PATH" \
      -h "$DB_HOST" \
      -p "$DB_PORT" \
      -U "$DB_USER" \
      -d "$DB_NAME" \
      -t -c "SELECT
                c.column_name,
                pgd.description
            FROM pg_catalog.pg_statio_all_tables as st
            INNER JOIN pg_catalog.pg_description pgd on (
                pgd.objoid = st.relid
            )
            INNER JOIN information_schema.columns c on (
                pgd.objsubid   = c.ordinal_position and
                c.table_schema = st.schemaname and
                c.table_name   = st.relname
            )
            WHERE c.table_schema = '$SCHEMA'
            AND c.table_name = '$TABLENAME';"
          )

    while IFS= read -r fila_comentario; do
      IFS="|" read -ra COMMENTS_PARAMS <<< "$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<< "$fila_comentario")"

      echo "COMMENT ON COLUMN $SCHEMA.$TABLENAME.$(echo "${COMMENTS_PARAMS[0]}" | xargs) IS '$(echo "${COMMENTS_PARAMS[1]}" | xargs)';" >> "$TABLES_PATH/$TABLENAME.sql"
    done <<< "$COMMENTS_COMPOSITION"

done



shopt -u nullglob  # buena practica: dejar la shell como estaba