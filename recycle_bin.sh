#################################################
# Linux Recycle Bin Simulation
# Author: Enrique Ornelas, Margarida Almeida
# Date: [Date]
# Description: Shell-based recycle bin system
#################################################

# Global Configuration
RECYCLE_BIN_DIR="$HOME/recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"

# Color codes for output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#################################################
# Function: initialize_recyclebin
# Description: Creates recycle bin directory structure
# Parameters: None
# Returns: 0 on success, 1 on failure
#################################################
initialize_recyclebin() {
  if [ ! -d "$RECYCLE_BIN_DIR" ]; then
    mkdir -p "$FILES_DIR"
    touch "$METADATA_FILE"
    echo "# Recycle Bin Metadata" > "$METADATA_FILE"
    echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"
    echo "Recycle bin initialized at $RECYCLE_BIN_DIR"
    return 0
  fi
  return 0
}

#################################################
# Function: generate_unique_id
# Description: Generates unique ID for deleted files
# Parameters: None
# Returns: Prints unique ID to stdout
#################################################
generate_unique_id() {
  local timestamp=$(date +%s)
  local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
  echo "${timestamp}_${random}"
}

#################################################
# Function: delete_file
# Description: Moves file/directory to recycle bin
# Parameters: $1 - path to file/directory
# Returns: 0 on success, 1 on failure
#################################################
delete_file() {
  # TODO: Implement this function
  local file_path="$1"

# TODO: Implement this function
local file_path="$1"

# Validate input
if [ -z "$file_path" ]; then
echo -e "${RED}Error: No file specified${NC}"
return 1
fi
for file_path in "$@"; do
# Check if file exists
    if [ ! -e "$file_path" ]; then
        echo -e "${RED}Error: File '$file_path' does not exist${NC}"
        return 1
    fi
    
    local base_name
    base_name=$(basename "$file_path")
    local ID
    ID=$(generate_unique_id)
    local new_name="${base_name}_${ID}"
    local deletion_date
    deletion_date=$(date +"%Y-%m-%d %H:%M:%S")

    mv "$file_path" "$FILES_DIR/$new_name"

        # Obter metadados using stat and file commands
        local original_path
        original_path=$(realpath "$file_path")
        local file_size
        file_size=$(stat -c "%s" "$FILES_DIR/$new_name")
        local file_type
        file_type=$(file -b "$FILES_DIR/$new_name")
        local permissions
        permissions=$(stat -c "%a" "$FILES_DIR/$new_name")
        local owner
        owner=$(stat -c "%U:%G" "$FILES_DIR/$new_name")

    #Append METADATA no diretório recycle bin.
    echo "$ID,$base_name,$original_path,$deletion_date,$file_size,\"$file_type\",$permissions,$owner" >> "$METADATA_FILE" # Name, size, permissions, owner
    echo -e "${GREEN}File '$file_path' moved to recycle bin as '$new_name'${NC}"
  done
   
    
# Your code here
# Hint: Get file metadata using stat command
# Hint: Generate unique ID
# Hint: Move file to FILES_DIR with unique ID
# Hint: Add entry to metadata file
echo "Delete function called with: $file_path"
return 0
}

#################################################
# Function: list_recycled
# Description: Lists all items in recycle bin
# Parameters: None
# Returns: 0 on success
#################################################
list_recycled() {
  local sort_by="${1:-date}"  # Default: ordena por data

  echo "=== Recycle Bin Contents ==="

  if [ ! -f "$METADATA_FILE" ] || [ ! -s "$METADATA_FILE" ]; then #f- se existe s- se tem tamanho
      echo "Recycle bin is empty"
      return 0
  fi

  local total_items=$(($(wc -l < "$METADATA_FILE") - 2))  #total de linhas - 1 (do header)

  if [ "$total_items" -eq 0 ]; then #sem o header esta vazio?
      echo "Recycle bin is empty"
      return 0
  fi

  # Print header
  printf "%-18s %-20s %-50s %-20s %-10s\n" "ID" "NAME" "ORIGINAL PATH" "DELETION DATE" "SIZE"
  printf "%-18s %-20s %-50s %-20s %-10s\n" "--" "----" "------------" "-------------" "----"

  # Calcular total_size ANTES do loop (fora do subshell)
  local total_size=$(tail -n +2 "$METADATA_FILE" | awk -F',' '{sum += $5} END {print sum+0}')
  
  # ORDENAÇÃO: Processar com sorting baseado no parâmetro
  case "$sort_by" in
      "name")
          # Ordenar por nome (coluna 2)
          tail -n +2 "$METADATA_FILE" | sort -t',' -k2 ;;
      "size")
          # Ordenar por tamanho (coluna 5) numericamente
          tail -n +2 "$METADATA_FILE" | sort -t',' -k5 -n ;;
      "date"|*)
          # Ordenar por data (coluna 4) - default
          tail -n +2 "$METADATA_FILE" | sort -t',' -k4 ;;
  esac | while IFS=',' read -r id name path deletion_date size type permissions owner; do
    if [[ "$id" =~ ^# || -z "$id" || "$id" == "ID" ]]; then
      continue
    fi
      # remove os espacos tr -d
      id=$(echo "$id" | tr -d ' ')
      name=$(echo "$name" | tr -d ' ')
      path=$(echo "$path" | tr -d ' ')
      deletion_date=$(echo "$deletion_date" | tr -d ' ')
      size=$(echo "$size" | tr -d ' ')

      if ! [[ "$size" =~ ^[0-9]+$ ]]; then
        size=0
      fi

      # converte o tamanho para humano
      local size_human=""
      if [ "$size" -lt 1024 ]; then
          size_human="${size}B"
      elif [ "$size" -lt 1048576 ]; then
          size_human="$(echo "scale=1; $size/1024" | bc) KB"
      else
          size_human="$(echo "scale=1; $size/1048576" | bc) MB"
      fi

      local display_id="${id:0:15}.." #so coloca os primeiros 15 caracteres e depois...
      local display_name="${name:0:18}.."
      

      printf "%-18s %-20s %-50s %-20s %-10s\n" "$display_id" "$display_name" "$path" "$deletion_date" "$size_human"
  done
  cat -A "$METADATA_FILE"

  echo ""
  echo "Total items: $total_items"
  
  # formatar o total_size também para humano
  local total_size_human=""
  if [ "$total_size" -lt 1048576 ]; then
      total_size_human="$(echo "scale=1; $total_size/1024" | bc) KB"
  else
      total_size_human="$(echo "scale=1; $total_size/1048576" | bc) MB"
  fi
  
  echo "Total size: $total_size_human"
  echo "Sorted by: $sort_by"
  
  return 0
}

#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
  # TODO: Implement this function
  local file_id="$1"

  if [ -z "$file_id" ]; then
    echo -e "${RED}Error: No file ID specified${NC}"
    return 1
  fi

  # Your code here
  # Hint: Search metadata for matching ID
  # Hint: Get original path from metadata
  # Hint: Check if original path exists
  # Hint: Move file back and restore permissions
  # Hint: Remove entry from metadata

  return 0
}

#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
  # TODO: Implement this function

  # Your code here
  # Hint: Ask for confirmation
  # Hint: Delete all files in FILES_DIR
  # Hint: Reset metadata file

  return 0
}

#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
search_recycled() {
  # TODO: Implement this function
  local pattern="$1"

  # Your code here
  # Hint: Use grep to search metadata

  return 0
}

#################################################
# Function: display_help
# Description: Shows usage information
# Parameters: None
# Returns: 0
#################################################
display_help() {
  cat << EOF
Linux Recycle Bin - Usage Guide

SYNOPSIS:
    $0 [OPTION] [ARGUMENTS]

OPTIONS:
    delete <file>    Move file/directory to recycle bin
    list             List all items in recycle bin
    restore <id>     Restore file by ID
    search <pattern> Search for files by name
    empty            Empty recycle bin permanently
    help             Display this help message

EXAMPLES:
    $0 delete myfile.txt
    $0 list
    $0 restore 1696234567_abc123
    $0 search "*.pdf"
    $0 empty

EOF
  return 0
}

#################################################
# Function: main
# Description: Main program logic
# Parameters: Command line arguments
# Returns: Exit code
#################################################
main() {
  # Initialize recycle bin
  initialize_recyclebin

  # Parse command line arguments
  case "$1" in
    delete)
      shift
      delete_file "$@"
      ;;
    list)
      list_recycled
      ;;
    restore)
      restore_file "$2"
      ;;
    search)
      search_recycled "$2"
      ;;
    empty)
      empty_recyclebin
      ;;
    help|--help|-h)
      display_help
      ;;
    *)
      echo "Invalid option. Use 'help' for usage information."
      exit 1
      ;;
  esac
}

# Execute main function with all arguments
main "$@"