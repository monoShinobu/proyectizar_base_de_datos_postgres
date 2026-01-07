#!/bin/bash

# $1 es la variable del ambiente
# $2 nombre de la rama con los cambios
# $3 nombre de la rama a comparar la anterior

PSQL_COMMAND="pg_dump"

source "$(dirname "$-1")/config/config_env.sh"

#La rama que tiene los cambios
TARGET_BRANCH="$2"

#La rama a la cual queremos comparar
ORIGIN_BRANCH="$3"


#Si es local borramos y creamos un nuevo archivo
#La ubicacion del archivo es en la del repo en la carpeta "diff_sp"
<<'COMMENT'
if [ "$EXEC_ENV" -eq 1 ]; then
    #Se crean los nombres del archivo y carpeta
    nombre_archivo_carpeta="${ORIGIN_BRANCH}_${TARGET_BRANCH}_$(date +%F)"
    nombre_archivo="$nombre_archivo_carpeta.sql"
    nombre_archivo_logs_git="git_logs_${nombre_archivo_carpeta}.txt"
    carpeta="$(dirname "$0")/../diff_sp/$nombre_archivo_carpeta"

    #Si el archivo ya existe lo borramos
    if [ -f "$carpeta/$nombre_archivo" ]; then
        echo -e "\n🗑️ Borrando $carpeta/$nombre_archivo..."
        rm "$carpeta/$nombre_archivo"

        echo -e "\n🗑️ Borrando $carpeta/$nombre_archivo_logs_git..."
        rm "$carpeta/$nombre_archivo_logs_git"
    else
        echo -e "\n⚠️ El archivo $ARCHIVO no existe. Creando..."
    fi
fi 
COMMENT

#Se crean los nombres del archivo y carpeta
nombre_archivo_carpeta="${ORIGIN_BRANCH}_${TARGET_BRANCH//\//_}_$(date +%F)"
nombre_archivo="$nombre_archivo_carpeta.sql"
nombre_archivo_logs_git="git_logs_${nombre_archivo_carpeta}.txt"
carpeta="$(dirname "$0")/../diff_sp"

#Si el archivo ya existe lo borramos
if [ -f "$carpeta/$nombre_archivo" ]; then
    echo -e "\n🗑️ Borrando $carpeta/$nombre_archivo..."
    rm "$carpeta/$nombre_archivo"

    echo -e "\n🗑️ Borrando $carpeta/$nombre_archivo_logs_git..."
    rm "$carpeta/$nombre_archivo_logs_git"
else
    echo -e "\n⚠️ El archivo $ARCHIVO no existe. Creando..."
fi

#Se crea la carpeta y archivo para los sp
mkdir -p "$carpeta" 
touch "$carpeta/$nombre_archivo"
touch "$carpeta/$nombre_archivo_logs_git"

# Para ejecutar solo los distintos
MOD_FILES=$(git diff --name-only origin/$ORIGIN_BRANCH..origin/$TARGET_BRANCH -- ./public/funciones)

echo -e "\n➕ Archivos agregados:"

for archivo in $MOD_FILES; do
    if [ -f "$archivo" ]; then
        #Se agregan los logs del multimo cambio por archivo
        # Obtener el último commit (hash y mensaje) para este archivo en la rama target
        commit_info=$(git log -1 --pretty=format:"%h %s" origin/$TARGET_BRANCH -- "$archivo")
        echo "$(basename $archivo)" >> "$carpeta/$nombre_archivo_logs_git"
        echo "$commit_info" >> "$carpeta/$nombre_archivo_logs_git"
        echo "" >> "$carpeta/$nombre_archivo_logs_git"  # salto de línea para separar

        #Creación del archivo de los sp que van a producción
        cat $archivo >> $carpeta/$nombre_archivo
        echo "" >> $carpeta/$nombre_archivo
        echo "✅ $(basename $archivo)"
    fi
done

shopt -u nullglob  # buena practica: dejar la shell como estaba