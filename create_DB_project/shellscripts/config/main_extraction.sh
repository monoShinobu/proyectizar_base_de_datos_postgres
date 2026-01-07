#!/bin/bash

source "$(dirname "$0")/config_env.sh"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$BASE_DIR/extraction/table_extraction.sh"
source "$BASE_DIR/extraction/functions_extraction.sh"

