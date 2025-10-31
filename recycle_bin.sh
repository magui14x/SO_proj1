#################################################
# Linux Recycle Bin Simulation
# Author: Enrique Ornelas, Margarida Almeida
# Date: [Date]
# Description: Shell-based recycle bin system
#################################################

# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"

# Color codes for output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#################################################F
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
    echo "AUTO_CLEANUP_DAYS=30" > "$CONFIG_FILE"
    echo "MAX_SIZE_MB=1024" >> "$CONFIG_FILE" 

    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SYSTEM: Recycle bin initialized" >> "$LOG_FILE"
    fi
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

check_disk_space(){
  local total_size
  total_size=$(tail -n +3 "$METADATA_FILE" | awk -F',' '{sum += $5} END {print sum}')
  echo "$total_size"
}

#################################################
# Function: delete_file
# Description: Moves file/directory to recycle bin
# Parameters: $1 - path to file/directory
# Returns: 0 on success, 1 on failure
#################################################
delete_file() {
  local max_size_mb=$(grep "^MAX_SIZE_MB=" "$CONFIG_FILE" | cut -d '=' -f2)
  local max_size_bytes=$((max_size_mb * 1024 * 1024))
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - DELETE operation started for files: $@" >> "$LOG_FILE"

  #input?
  if [ "$#" -eq 0 ]; then
    echo -e "${RED}Error: No file specified${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: No file specified" >> "$LOG_FILE"
    return 1
  fi

  
  for file_path in "$@"; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Processing file: '$file_path'" >> "$LOG_FILE"
    #se for importante n apaga
    if [[ "$(basename "$file_path")" == "recycle_bin.sh" || "$file_path" == "$METADATA_FILE" || "$file_path" == "$RECYCLE_BIN_DIR" || "$file_path" == "$CONFIG_FILE" || "$file_path" == "$LOG_FILE" ]]; then
      echo -e "${RED}You can't erase this file.${NC} (It's... kind of important...)"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Attempted to delete protected file: '$file_path'" >> "$LOG_FILE" 
      continue
    fi

      #ficheiro existe
    if [ ! -e "$file_path" ]; then
      echo -e "${RED}Error non-existant: '$file_path' does not exist${NC}"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: File not found. '$file_path' " >> "$LOG_FILE"
      continue
    fi

     # Handle symbolic links
    if [ -L "$file_path" ]; then
    link_target=$(readlink "$file_path")
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Detected symbolic link: '$file_path' -> '$link_target'" >> "$LOG_FILE"
    fi


    # If it's a directory (but not a symlink pointing to a directory), delete contents first
    # This prevents following and deleting the contents of directories through symbolic links
    if [[ -d "$file_path" && ! -L "$file_path" ]]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Recursively deleting directory contents: '$file_path'" >> "$LOG_FILE"
      find "$file_path" -mindepth 1 | while read -r sub_item; do
        [[ -e "$sub_item" ]] && delete_file "$sub_item"
      done
    fi
  
  
  # Collect metadata BEFORE moving
  local base_name
  base_name=$(basename "$file_path")
  base_name="${base_name//[,]/}" 
  local ID
  ID=$(generate_unique_id)
  local new_name="${base_name}_${ID}"   
  local deletion_date
  deletion_date=$(date +"%Y-%m-%d %H:%M:%S")
  local original_path
  original_path=$(realpath "$file_path")
  original_path="${original_path//[,]/}" 
  local file_size
  file_size=$(stat -c "%s" "$file_path")
  local file_type
  file_type=$(file -b "$file_path")
  file_type="${file_type//[,]/}"
  local permissions
  permissions=$(stat -c "%a" "$file_path")
  local owner
  owner=$(stat -c "%U:%G" "$file_path")

  local current_usage
  current_usage=$(check_disk_space)
  local new_total
  new_total=$(( file_size + current_usage ))

  if [ "$new_total" -gt "$max_size_bytes" ]; then
    echo -e "${YELLOW}This File is too large for the current max size in recycle bin (${max_size_mb} MB).${NC}"
    echo "It is advised too either change the limit or to not do this deletion. "
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SIZE ERROR: File too large:'$file_path' " >> "$LOG_FILE"
    continue
  fi

  exec 200>>"$METADATA_FILE"
  flock -n 200 || {
  echo -e "${RED}Another deletion is in progress. Try again shortly.${NC}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Could not acquire lock on metadata file" >> "$LOG_FILE"
  continue  
  }

  # Move to recycle bin
# Try moving the file
if mv "$file_path" "$FILES_DIR/$new_name" 2>/dev/null; then
  # Success
  echo "$ID,$base_name,$original_path,$deletion_date,$file_size,\"$file_type\",$permissions,$owner" >> "$METADATA_FILE"
  echo -e "${GREEN}'$file_path' moved to recycle bin as ${NC}${YELLOW}'$new_name'${NC}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: '$file_path' moved successfully" >> "$LOG_FILE"
else
  # Failure
  echo -e "${RED}Error: Failed to move '$file_path' (insufficient permissions or locked file)${NC}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Failed to move '$file_path' to recycle bin" >> "$LOG_FILE"
  flock -u 200  # release the lock
  continue
fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') - METADATA: Added entry for ID '$ID' ('$base_name')" >> "$LOG_FILE"

  echo "Delete function called with: $file_path"
  done

  echo "$(date '+%Y-%m-%d %H:%M:%S') - DELETE operation completed successfully for all files" >> "$LOG_FILE"

  return 0
  }



#################################################
# Function: list_recycled
# Description: Lists all items in recycle bin
# Parameters: --detailed for detailed view
# Returns: 0 on success
#################################################
list_recycled() {
    local max_size_mb=$(grep "^MAX_SIZE_MB=" "$CONFIG_FILE" | cut -d '=' -f2)
    max_size_bytes=$((max_size_mb * 1024 * 1024))
    local sort_by="${RECYCLE_BIN_SORT_BY:-date}"
    local display_path
    local display_name
    local detailed_mode=false

    # Check for --detailed flag
    if [[ "$1" == "--detailed" || "$1" == "-d" ]]; then
        detailed_mode=true
    fi

    echo "=== Recycle Bin Contents ==="

    if [ ! -f "$METADATA_FILE" ] || [ ! -s "$METADATA_FILE" ]; then
        echo "Error: Metadata is absolutely empty"
        return 1
    fi

    local total_items=$(($(wc -l < "$METADATA_FILE") - 2))

    if [ "$total_items" -eq 0 ]; then
        echo "Recycle bin is empty"
        return 0
    fi

    # Calcular total_size
    local total_size=$(tail -n +2 "$METADATA_FILE" | awk -F',' '{sum += $5} END {print sum+0}')

    if [ "$detailed_mode" = true ]; then
        # DETAILED MODE - Full information per item
        echo "DETAILED VIEW"
        echo "============="
        
        local count=0
        # ORDENAÇÃO baseada na variável de ambiente
        case "$sort_by" in
            "name")
                sorted_data=$(tail -n +2 "$METADATA_FILE" | sort -t',' -k2) ;;
            "size")
                sorted_data=$(tail -n +2 "$METADATA_FILE" | sort -t',' -k5 -n) ;;
            "date"|*)
                sorted_data=$(tail -n +2 "$METADATA_FILE" | sort -t',' -k4) ;;
        esac

        echo "$sorted_data" | while IFS=',' read -r id name path deletion_date size type permissions owner; do
            if [[ "$id" =~ ^# || -z "$id" || "$id" == "ID" ]]; then
                continue
            fi

            # Clean fields
            id=$(echo "$id" | tr -d ' ')
            name=$(echo "$name")
            path=$(echo "$path")
            deletion_date=$(echo "$deletion_date")
            size=$(echo "$size" | tr -d ' ')
            type=$(echo "$type" | sed 's/^"//;s/"$//')
            permissions=$(echo "$permissions" | tr -d ' ')
            owner=$(echo "$owner" | tr -d ' ')

            if ! [[ "$size" =~ ^[0-9]+$ ]]; then
                continue
            fi

            # Convert size to human readable
            local size_human=""
            if [ "$size" -lt 1024 ]; then
                size_human="${size}B"
            elif [ "$size" -lt 1048576 ]; then
                size_human="$(echo "scale=1; $size/1024" | bc) KB"
            else
                size_human="$(echo "scale=1; $size/1048576" | bc) MB"
            fi

            ((count++))

            # Linha separadora antes de cada item (exceto o primeiro)
            if [ $count -gt 1 ]; then
                echo "------------------------------------------------------------------------"
            fi

            echo "ITEM $count:"
            printf "  ${GREEN}%-15s${NC}: %s\n" "ID" "$id"
            printf "  ${GREEN}%-15s${NC}: %s\n" "Name" "$name"
            printf "  ${GREEN}%-15s${NC}: %s\n" "Original Path" "$path"
            printf "  ${GREEN}%-15s${NC}: %s\n" "Deleted" "$deletion_date"
            printf "  ${GREEN}%-15s${NC}: %s (%s)\n" "Size" "$size_human" "$size bytes"
            printf "  ${GREEN}%-15s${NC}: %s\n" "Type" "$type"
            printf "  ${GREEN}%-15s${NC}: %s\n" "Permissions" "$permissions"
            printf "  ${GREEN}%-15s${NC}: %s\n" "Owner" "$owner"
            
            # Show actual file in recycle bin
            local recycled_file
            recycled_file=$(find "$FILES_DIR" -name "*_${id}" \( -type f -o -type l \) 2>/dev/null | head -n 1)
            if [ -n "$recycled_file" ]; then
                printf "  ${GREEN}%-15s${NC}: %s\n" "Recycled as" "$(basename "$recycled_file")"
                
                # Additional file info
                if [ -f "$recycled_file" ]; then
                    local file_info
                    file_info=$(file -b "$recycled_file")
                    printf "  ${GREEN}%-15s${NC}: %s\n" "File Info" "$file_info"
                    
                    # For text files, show first line preview
                    if [[ "$file_info" == *"text"* ]] && [ "$size" -lt 10240 ]; then
                        local first_line
                        first_line=$(head -n 1 "$recycled_file" 2>/dev/null | cut -c1-50)
                        if [ -n "$first_line" ]; then
                            printf "  ${GREEN}%-15s${NC}: %s\n" "Preview" "$first_line..."
                        fi
                    fi
                fi
            fi
            echo ""
        done

    else
        # NORMAL MODE - Compact table view
        echo "COMPACT VIEW"
        echo "============"
        
        # Print header
        printf "%-20s %-20s %-50s %-25s %-13s\n" "ID" "NAME" "ORIGINAL PATH" "DELETION DATE" "SIZE"
        printf "%-20s %-20s %-50s %-25s %-13s\n" "--" "----" "------------" "-------------" "----"

        # ORDENAÇÃO baseada na variável de ambiente
        case "$sort_by" in
            "name")
                sorted_data=$(tail -n +2 "$METADATA_FILE" | sort -t',' -k2) ;;
            "size")
                sorted_data=$(tail -n +2 "$METADATA_FILE" | sort -t',' -k5 -n) ;;
            "date"|*)
                sorted_data=$(tail -n +2 "$METADATA_FILE" | sort -t',' -k4) ;;
        esac

        echo "$sorted_data" | while IFS=',' read -r id name path deletion_date size type permissions owner; do
            if [[ "$id" =~ ^# || -z "$id" || "$id" == "ID" ]]; then
                continue
            fi

            # Clean fields
            id=$(echo "$id" | tr -d ' ')
            name=$(echo "$name")
            path=$(echo "$path")
            deletion_date=$(echo "$deletion_date")
            size=$(echo "$size" | tr -d ' ')

            if ! [[ "$size" =~ ^[0-9]+$ ]]; then
                continue
            fi

            # Convert size to human readable
            local size_human=""
            if [ "$size" -lt 1024 ]; then
                size_human="${size}B"
            elif [ "$size" -lt 1048576 ]; then
                size_human="$(echo "scale=1; $size/1024" | bc) KB"
            else
                size_human="$(echo "scale=1; $size/1048576" | bc) MB"
            fi

            # Truncate long names and paths for display
            if [ ${#name} -gt 18 ]; then
                display_name="${name:0:18}.."
            else
                display_name="$name"
            fi
            
            if [ ${#path} -gt 48 ]; then
                display_path="${path:0:48}.."
            else
                display_path="$path"
            fi

            printf "%-20s %-20s %-50s %-25s %-13s\n" "$id" "$display_name" "$display_path" "$deletion_date" "$size_human"
        done
    fi

    # Common footer for both modes
    echo ""
    echo "=== Summary ==="
    echo "Total items: $total_items"
    
    # Format total_size for human readable
    local total_size_human=""
    if [ "$total_size" -lt 1024 ]; then
        total_size_human="${total_size}B"
    elif [ "$total_size" -lt 1048576 ]; then
        total_size_human="$(echo "scale=1; $total_size/1024" | bc) KB"
    else
        total_size_human="$(echo "scale=1; $total_size/1048576" | bc) MB"
    fi

    usage_percent=$(awk -v used="$total_size" -v max="$max_size_bytes" 'BEGIN {printf "%.2f", (used / max) * 100}')
    
    echo "Total size: $total_size_human"
    echo "Sorted by: $sort_by"
    echo "Percentage usage: ${usage_percent}% of ${max_size_mb}MB"
    
    if [ "$usage_percent" -gt 90 ]; then
        echo -e "${YELLOW}Usage close to the limit, consider using auto_cleanup to erase old files${NC}"
    fi

    if [ "$detailed_mode" = false ]; then
        echo ""
        echo "View options:"
        echo "  ./recycle_bin.sh list --detailed    # Detailed view with full information"
        echo "  ./recycle_bin.sh list               # Compact table view (default)"
        echo ""
        echo "Sorting options:"
        echo "  export RECYCLE_BIN_SORT_BY=name    # Sort by name"
        echo "  export RECYCLE_BIN_SORT_BY=size    # Sort by size" 
        echo "  export RECYCLE_BIN_SORT_BY=date    # Sort by date (default)"
    fi

    return 0
}
#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
    local search_term="$1"
    
    # Log the restoration attempt
    echo "$(date '+%Y-%m-%d %H:%M:%S') - RESTORE: Attempting to restore '$search_term'" >> "$LOG_FILE"
    
    if [ -z "$search_term" ]; then
        echo -e "${RED}Error: No file ID or filename specified${NC}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: No search term provided for restore" >> "$LOG_FILE"
        return 1
    fi

    # Verificar se o metadata file existe
    if [ ! -f "$METADATA_FILE" ]; then
        echo -e "${RED}Error: Recycle bin is not initialized${NC}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Recycle bin not initialized" >> "$LOG_FILE"
        return 1
    fi

    if [ ! -s "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE") -le 2 ]; then
        echo -e "${RED}Error: Recycle bin is empty${NC}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Recycle bin empty during restore attempt" >> "$LOG_FILE"
        return 1
    fi

    # Procurar de forma mais flexível - CORREÇÃO: ignorar cabeçalho e buscar melhor
    local metadata_entry
    metadata_entry=$(tail -n +3 "$METADATA_FILE" | awk -F ',' -v term="$search_term" '
    {
        clean_id = $1;
        gsub(/^[ \t]+|[ \t]+$/, "", clean_id);
        clean_name = $2;
        gsub(/^[ \t]+|[ \t]+$/, "", clean_name);
        if (tolower(clean_id) == tolower(term) || index(tolower(clean_name),tolower(term)) > 0 ){
            print $0;
        }
    }' | head -n 1)  # Pegar apenas a primeira ocorrência

    if [ -z "$metadata_entry" ]; then
        echo -e "${RED}Error: No file found matching '$search_term'${NC}"
        echo ""
        echo "Tips:"
        echo "• Use './recycle_bin.sh list' to see all files"
        echo "• Use the exact ID from the list above"
        echo "• Or use part of the filename"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: No match found for '$search_term'" >> "$LOG_FILE"
        return 1
    fi

    # Parse metadata fields
    local id original_name original_path deletion_date file_size file_type permissions owner
    IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$metadata_entry"
    
    # Clean up fields
    file_type=$(echo "$file_type" | sed 's/^"//;s/"$//')
    original_name=$(echo "$original_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    original_path=$(echo "$original_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    id=$(echo "$id" | tr -d '[:space:]')
    permissions=$(echo "$permissions" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    echo "File details:"
    echo "• ID: $id"
    echo "• Name: $original_name"
    echo "• Original path: $original_path"
    echo "• Deleted: $deletion_date"
    echo "• Size: $file_size bytes"
    echo "• Permissions: $permissions"
    echo ""

    # Find the actual file in recycle bin (allow regular files, symbolic links AND directories) - CORREÇÃO
    local recycled_file
    recycled_file=$(find "$FILES_DIR" -name "*_${id}" \( -type f -o -type l -o -type d \) 2>/dev/null | head -n 1)
    
    if [ -z "$recycled_file" ]; then
        echo -e "${RED}Error: Physical file not found in recycle bin${NC}"
        echo "Looking for pattern: '*_${id}'"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Physical file missing for ID '$id'" >> "$LOG_FILE"
        return 1
    fi

    echo "Physical file found: $recycled_file"
    echo ""

    # Check disk space at destination - NOVO: verificar espaço em disco
    local available_space
    available_space=$(df "$(dirname "$original_path")" 2>/dev/null | awk 'NR==2 {print $4 * 1024}')  # Convert to bytes
    if [ -n "$available_space" ] && [ "$available_space" -lt "$file_size" ]; then
        echo -e "${RED}Error: Insufficient disk space at destination${NC}"
        echo "Available: $(numfmt --to=iec $available_space), Required: $(numfmt --to=iec $file_size)"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Insufficient disk space for restoring '$id'" >> "$LOG_FILE"
        return 1
    fi

    # Check if original directory exists
    local original_dir
    original_dir=$(dirname "$original_path")
    
    if [ ! -d "$original_dir" ]; then
        echo -e "${YELLOW}Warning: Original directory '$original_dir' no longer exists${NC}"
        read -p "Create directory? [y/N]: " create_dir
        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
            if ! mkdir -p "$original_dir" 2>/dev/null; then
                echo -e "${RED}Error: Failed to create directory '$original_dir'${NC}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Failed to create directory '$original_dir'" >> "$LOG_FILE"
                return 1
            fi
            echo -e "${GREEN}Directory created successfully${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Created directory: '$original_dir'" >> "$LOG_FILE"
        else
            echo "Restoration cancelled"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - CANCELLED: User cancelled due to missing directory" >> "$LOG_FILE"
            return 1
        fi
    fi

    # CORREÇÃO: Fechamento do bloco if que estava incompleto
    if [ ! -w "$original_dir" ]; then
        echo -e "${YELLOW}Warning: No write permission for '$original_dir'${NC}"
        read -p "Attempt to grant write permission? [y/N]: " fix_perm
        if [[ "$fix_perm" =~ ^[Yy]$ ]]; then
            if chmod u+wx "$original_dir" 2>/dev/null; then
                echo -e "${GREEN}Write permission granted to '$original_dir'${NC}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - Granted write permission to: '$original_dir'" >> "$LOG_FILE"
            else
                echo -e "${RED}Error: Failed to change permissions. You may need root access.${NC}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Failed to change permissions for '$original_dir'" >> "$LOG_FILE"
                return 1
            fi
        else
            echo "Restoration cancelled due to insufficient permissions"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - CANCELLED: Insufficient permissions for '$original_dir'" >> "$LOG_FILE"
            return 1
        fi
    fi

    # Handle file existence conflicts
    local final_destination="$original_path"
    local conflict_resolution="direct"
    
    if [ -e "$original_path" ]; then
        echo -e "${YELLOW}Warning: A file already exists at '$original_path'${NC}"
        echo "Choose an option:"
        echo "1) Overwrite existing file"
        echo "2) Restore with modified name (append timestamp)"
        echo "3) Cancel operation"
        
        local choice
        while true; do
            read -p "Enter your choice [1-3]: " choice
            case "$choice" in
                1)
                    if [ -d "$original_path" ] && [ ! -L "$original_path" ]; then
                        # Para diretórios, precisa remover cuidadosamente
                        if ! rm -rf "$original_path" 2>/dev/null; then
                            echo -e "${RED}Error: Cannot overwrite directory. Permission denied or directory not empty.${NC}"
                            echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Cannot overwrite directory '$original_path'" >> "$LOG_FILE"
                            return 1
                        fi
                    else
                        # Para arquivos e symlinks
                        if ! rm -f "$original_path" 2>/dev/null; then
                            echo -e "${RED}Error: Cannot overwrite file. Permission denied.${NC}"
                            echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Cannot overwrite file '$original_path'" >> "$LOG_FILE"
                            return 1
                        fi
                    fi
                    conflict_resolution="overwrite"
                    echo "Overwriting existing file..."
                    ;;
                2)
                    local timestamp
                    timestamp=$(date +%Y%m%d_%H%M%S)
                    local base_name
                    base_name=$(basename "$original_path")
                    local extension=""
                    local name_part="$base_name"
                    
                    # Handle files with extensions
                    if [[ "$base_name" =~ ^(.+)\.([^.]+)$ ]]; then
                        name_part="${BASH_REMATCH[1]}"
                        extension=".${BASH_REMATCH[2]}"
                    fi
                    
                    final_destination="$(dirname "$original_path")/${name_part}_restored_${timestamp}${extension}"
                    conflict_resolution="renamed"
                    echo "Will restore as: $(basename "$final_destination")"
                    ;;
                3)
                    echo "Restoration cancelled"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - CANCELLED: User cancelled due to file conflict" >> "$LOG_FILE"
                    return 1
                    ;;
                *)
                    echo "Invalid choice. Please enter 1, 2, or 3."
                    ;;
            esac
            [[ "$choice" =~ ^[123]$ ]] && break
        done
    fi

    # Attempt to restore the file
    echo "Restoring file to: $final_destination"
    
    if ! mv "$recycled_file" "$final_destination" 2>/dev/null; then
        echo -e "${RED}Error: Failed to move file to destination${NC}"
        echo "Check permissions and try again"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Failed to move '$recycled_file' to '$final_destination'" >> "$LOG_FILE"
        return 1
    fi

    # Restore original permissions
    if [ -n "$permissions" ] && [[ "$permissions" =~ ^[0-7]+$ ]]; then
        if chmod "$permissions" "$final_destination" 2>/dev/null; then
            echo -e "${GREEN}Permissions restored to $permissions${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Restored permissions to '$permissions' for '$final_destination'" >> "$LOG_FILE"
        else
            echo -e "${YELLOW}Warning: Could not restore permissions (may require root)${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Could not restore permissions for '$final_destination'" >> "$LOG_FILE"
        fi
    fi

    # Remove entry from metadata
    local temp_file
    temp_file=$(mktemp)
    # CORREÇÃO: método mais robusto para remover entrada
    if awk -F ',' -v target_id="$id" '$1 != target_id' "$METADATA_FILE" > "$temp_file" 2>/dev/null; then
        if mv "$temp_file" "$METADATA_FILE"; then
            echo -e "${GREEN}Metadata updated${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Removed metadata entry for ID '$id'" >> "$LOG_FILE"
        else
            echo -e "${YELLOW}Warning: Could not update metadata file${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Could not update metadata file" >> "$LOG_FILE"
            rm -f "$temp_file"
        fi
    else
        echo -e "${YELLOW}Warning: Could not process metadata file${NC}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Could not process metadata file" >> "$LOG_FILE"
        rm -f "$temp_file"
    fi

    # Log the restoration - CORREÇÃO: usar LOG_FILE principal
    local log_entry
    log_entry="$(date '+%Y-%m-%d %H:%M:%S') - RESTORED: $original_name (ID: $id) to $final_destination (resolution: $conflict_resolution)"
    echo "$log_entry" >> "$LOG_FILE"
    
    echo -e "${GREEN}File successfully restored to: $final_destination${NC}"
    echo "Restoration completed and logged"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: Restoration completed for '$id'" >> "$LOG_FILE"

    return 0
}
#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
  local target="$1"
  local force=false

  # Verifica se o argumento é --force
  if [[ "$target" == "--force" ]]; then
    force=true
    target=""
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') - EMPTY: Operation started" >> "$LOG_FILE"

  # MODO 1: Apagar tudo
  if [[ -z "$target" ]]; then
    if [ "$force" = false ]; then
      echo -e "${YELLOW}Are you sure you want to permanently delete ALL files in the recycle bin?${NC}"
      read -rp "Type 'yes' to confirm: " REPLY
      if [[ "$REPLY" != "yes" ]]; then
        echo "Operation cancelled."
        echo "$(date '+%Y-%m-%d %H:%M:%S') - CANCELLED: User aborted full deletion" >> "$LOG_FILE"
        return 1
      fi
    fi

    local total_deleted=0
    for file in "$FILES_DIR"/*; do
      [ -e "$file" ] || continue
      rm -rf "$file"
      ((total_deleted++))
    done

    # Reset metadata
    echo "# Recycle Bin Metadata" > "$METADATA_FILE"
    echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"

    echo -e "${GREEN}All files permanently deleted (${total_deleted} items).${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - DELETED: All files purged from recycle bin (${total_deleted} items)" >> "$LOG_FILE"
    return 0
  fi

  # MODO 2: Apagar item específico por nome ou ID
  local matches=()
  local index=1

  while IFS=',' read -r id name path date size type perms owner; do
    if [[ "$id" == "$target" || "$name" == "$target" ]]; then
      matches+=("$id,$name,$path,$date,$size,$type,$perms,$owner")
      echo "[$index] ID: $id | Name: $name | Deleted on: $date | Size: ${size}B | Type: $type"
      ((index++))
    fi
  done < <(tail -n +3 "$METADATA_FILE")

  if [ "${#matches[@]}" -eq 0 ]; then
    echo -e "${RED}No matching files found for '$target'${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: No match found for '$target'" >> "$LOG_FILE"
    return 1
  fi

  echo ""
  echo "Choose the index of the file you want to permanently delete. Anything else to cancel."
  read -rp "Selection: " selection

  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#matches[@]}" ]; then
    echo "Invalid selection. Operation cancelled."
    return 1
  fi

  local selected="${matches[$((selection-1))]}"
  IFS=',' read -r id name path date size type perms owner <<< "$selected"
  local full_name="${name}_${id}"
  local full_path="$FILES_DIR/$full_name"

  if [ -e "$full_path" ]; then
    if rm -rf "$full_path"; then
      grep -v "^$id," "$METADATA_FILE" > "$METADATA_FILE.tmp" && mv "$METADATA_FILE.tmp" "$METADATA_FILE"
      echo -e "${GREEN}File '$name' (ID: $id) permanently deleted.${NC}"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - DELETED: File '$name' (ID: $id) permanently removed" >> "$LOG_FILE"
    else
      echo -e "${RED}Error: Failed to delete file '${full_name}'${NC}"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Failed to delete '$full_name'" >> "$LOG_FILE"
      return 1
    fi
  else
    echo -e "${YELLOW}Warning: File not found in recycle bin${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: File '$full_name' missing during deletion" >> "$LOG_FILE"
  fi

  return 0
}

#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
search_recycled() {
  shopt -s nocasematch
  local pattern="$1"
  local found=0
  local index=1

  if [[ -z "$pattern" ]]; then
    echo -e "${RED}Error: No search pattern provided${NC}"
    return 1
  fi

  if [ ! -f "$METADATA_FILE" ] || [ ! -s "$METADATA_FILE" ]; then
    echo -e "${YELLOW}Recycle bin is empty or not initialized${NC}"
    return 1
  fi

  echo "=== Search Results for pattern: '$pattern' ==="
  printf "%-5s %-20s %-50s %-25s %-15s %-10s\n" "IDX" "NAME" "ORIGINAL PATH" "DELETION DATE" "TYPE" "ID"
  printf "%-5s %-20s %-50s %-25s %-15s %-10s\n" "----" "--------------------" "--------------------------------------------------" "-------------------------" "---------------" "----------"

  while IFS=',' read -r id name path date size type perms owner; do

    # Clean fields
    name=$(echo "$name" | xargs)
    path=$(echo "$path" | xargs)
    type=$(echo "$type" | sed 's/^"//;s/"$//')

    # Match by extension or pattern
    if [[ "$pattern" == \*.* ]]; then
      local ext="${pattern#*.}"
      if [[ "$name" =~ \.${ext}$ ]]; then
        printf "%-5s %-20s %-50s %-25s %-15s %-10s\n" "$index" "$name" "$path" "$date" "$type" "$id"
        ((index++))
        found=1
      fi
    else
      if [[ "$name" =~ "$pattern" || "$path" =~ "$pattern" ]]; then
        printf "%-5s %-20s %-50s %-25s %-15s %-10s\n" "$index" "$name" "$path" "$date" "$type" "$id"
        ((index++))
        found=1
      fi
    fi
  done < <(tail -n +3 "$METADATA_FILE")

  if [[ "$found" -eq 0 ]]; then
    echo -e "${YELLOW}No matching files found for pattern: '$pattern'${NC}"
    return 1
  fi

  echo ""
  echo "Total matches: $((index - 1))"
  return 0
}

#################################################
# Function: auto_cleanup
# Description: Erases files before a determined date.
# Parameters: None
# Returns: 0
#################################################

auto_cleanup() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}No config file found. Skipping auto-cleanup.${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - AUTO_CLEANUP: Skipped due to missing config file" >> "$LOG_FILE"
    return 1
  fi

  local cleanup_days
  cleanup_days=$(grep "^AUTO_CLEANUP_DAYS=" "$CONFIG_FILE" | cut -d '=' -f2)

  if ! [[ "$cleanup_days" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Invalid AUTO_CLEANUP_DAYS value in config.${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - AUTO_CLEANUP: Invalid retention value '$cleanup_days'" >> "$LOG_FILE"
    return 1
  fi

  local present_date
  present_date=$(date +%s)
  local deleted_ids=()
  local deleted_count=0
  local total_freed=0

  while IFS=',' read -r id name path date size type perms owner; do
    

    if ! deletion_date=$(date -d "$date" +%s 2>/dev/null); then
      echo -e "${YELLOW}Skipping entry with invalid date: $date${NC}"
      continue
    fi

    local age_days=$(( (present_date - deletion_date) / 86400 ))
    if [[ "$age_days" -ge "$cleanup_days" ]]; then
      local file_path="$FILES_DIR/${name}_${id}"
      if [ -e "$file_path" ]; then
        echo -e "${GREEN}Deleted: '$name' (ID: $id), Age: ${age_days} days${NC}"
        deleted_ids+=("$id")
        ((deleted_count++))
        ((total_freed+=size))

        if [ -d "$file_path" ]; then
          rmdir "$file_path" 2>/dev/null || rm -rf "$file_path"
        else
          rm -f "$file_path"
        fi

        echo "$(date '+%Y-%m-%d %H:%M:%S') - AUTO_CLEANUP: Deleted '$name' (ID: $id)" >> "$LOG_FILE"
      fi
    fi
  done < <(tail -n +3 "$METADATA_FILE")

  if [ "${#deleted_ids[@]}" -gt 0 ]; then
    grep -v -E "^(${deleted_ids[*]// /|})," "$METADATA_FILE" > "$METADATA_FILE.tmp" && mv "$METADATA_FILE.tmp" "$METADATA_FILE"
  fi

  # Summary
  echo ""
  echo "=== Auto-Cleanup Summary ==="
  echo "Retention threshold: $cleanup_days days"
  echo "Files deleted: $deleted_count"
  echo "Space freed: $(numfmt --to=iec $total_freed)"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - AUTO_CLEANUP: Completed. Deleted $deleted_count files, freed $(numfmt --to=iec $total_freed)" >> "$LOG_FILE"

  return 0
}

#################################################
# Function: Show Statistics
# Description: Shows recycle_bin information
# Parameters: None
# Returns: 0
#################################################

show_statistics() {
  local max_size_mb=$(grep "^MAX_SIZE_MB=" "$CONFIG_FILE" | cut -d '=' -f2)
  max_size_bytes=$((max_size_mb * 1024 * 1024))
  
  if [ ! -f "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 1 ]; then
    echo "Recycle bin is empty."
    return 1
  fi

  echo "📊 Recycle Bin Statistics"
  echo "-------------------------"

  # Total items
  total_items=$(tail -n +3 "$METADATA_FILE" | wc -l)
  echo "Total items: $total_items"

  # Total size in bytes
  total_size=$(tail -n +3 "$METADATA_FILE" | awk -F',' '{sum += $5} END {print sum}')
  human_size=$(numfmt --to=iec --suffix=B "$total_size")
  usage_percent=$(awk -v used="$total_size" -v max="$max_size_bytes" 'BEGIN {printf "%.2f", (used / max) * 100}')
  echo "Total size: $human_size"
  echo "Percentage usage: ${usage_percent}% of ${max_size_mb}MB"

  if [ "$usage_percent" -gt 90 ]; then
    echo -e "${YELLOW}Usable space almost maxed, consider running auto_clean up to erase old files, or increasing the max space that the bin can use.${NC} "
  elif [ "$usage_percent" -gt 100 ]; then
    echo "${RED}Usage above 100%? How did you even do that?${NC}" 
  fi

  # Breakdown by type
  dir_count=$(tail -n +3 "$METADATA_FILE" | awk -F',' '$6 ~ /directory/ {count++} END {print count+0}')
  file_count=$(( $total_items - $dir_count ))
  echo "Files: $file_count"
  echo "Directories: $dir_count"

  # Oldest and newest deletion dates
  oldest=$(tail -n +3 "$METADATA_FILE" | awk -F',' '{print $4}' | sort | head -n 1)
  newest=$(tail -n +3 "$METADATA_FILE" | awk -F',' '{print $4}' | sort | tail -n 1)
  echo "Oldest deletion: $oldest"
  echo "Most recent deletion: $newest"

  
  if ! [[ "$file_count" =~ ^[0-9]+$ ]] || [ "$file_count" -le 0 ]; then
    avg_size=0
  else
    # total_size is already computed above as the sum of sizes for all entries
    avg_size=$(( total_size / file_count ))
  fi
  human_avg=$(numfmt --to=iec --suffix=B "$avg_size")
  echo "Average file size: $human_avg"
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
    $0 [COMMAND] [ARGUMENTS]

COMMANDS:
    delete <file> [file ...]     Move one or more files/directories to the recycle bin
    list                         List all items currently in the recycle bin
    restore <name or ID>         Restore a file by its original name or unique ID
    search <pattern>             Search for files by name or original path (supports wildcards)
    empty                        Permanently delete all items in the recycle bin (confirmation required)
    empty <name>                 Search for a file and choose which matching item to permanently delete
    auto                         Automatically delete files older than the configured retention period
    help                         Display this help message

CONFIGURATION:
    Settings are stored in:
        $CONFIG_FILE

    Key options include:
        MAX_SIZE_MB           Maximum allowed size of recycle bin (in MB)
        AUTO_CLEANUP_DAYS     Number of days before auto-deletion (default: 30)

EXAMPLES:
    $0 delete myfile.txt
    $0 delete file1.txt folder2/
    $0 list
    $0 restore 1696234567_abc123
    $0 restore "report.docx"
    $0 search "*.pdf"
    $0 empty
    $0 empty "test.txt"
    $0 auto
    $0 help

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
      list_recycled "$2"
      ;;
    restore)
      restore_file "$2"
      ;;
    search)
      search_recycled "$2"
      ;;
    empty)
      empty_recyclebin "$2"
      ;;
    help|--help|-h)
      display_help
      ;;
    auto|auto_cleanup|auto_clean|cleanup)
      auto_cleanup
      ;;  
    stats|statistics|show_stats|show_statistics)
      show_statistics
      ;;
    *)
      echo "Invalid option. Use 'help' for usage information."
      exit 1
      ;;
  esac
}

# Execute main function with all arguments
main "$@"