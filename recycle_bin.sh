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
    [{ ! -f "$CONFIG_FILE" }] && {
      echo "MAX_SIZE=104857600" > "$CONFIG_FILE" # 100MB default
      echo "AUTO_EMPTY_DAYS=30" >> "$CONFIG_FILE" # 30 days default
    }
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
    local file_path="$1"

    # Validate input
    if [ -z "$file_path" ]; then
      echo -e "${RED}Error: No file specified${NC}"
      return 1
    fi

    if [[ "$(basename "$file_path")" == "recycle_bin.sh" || "$file_path" == "$METADATA_FILE" || "$file_path" == "$RECYCLE_BIN_DIR" || "$file_path" == "$CONFIG_FILE" ]]; then
      echo -e "${RED}You can't erase this file.${NC} (It's... kind of important...)"
      return 1
    fi

    if [ ! -e "$file_path" ]; then
      echo -e "${RED}Error non-existant: '$file_path' does not exist${NC}"
      return 1
    fi

    # If it's a directory (but not a symlink pointing to a directory), delete contents first
    # This prevents following and deleting the contents of directories through symbolic links
    if [[ -d "$file_path" && ! -L "$file_path" ]]; then
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
    local permissions
    permissions=$(stat -c "%a" "$file_path")
    local owner
    owner=$(stat -c "%U:%G" "$file_path")

    # Move to recycle bin
    mv "$file_path" "$FILES_DIR/$new_name"

    # Append metadata
    echo "$ID,$base_name,$original_path,$deletion_date,$file_size,\"$file_type\",$permissions,$owner" >> "$METADATA_FILE"
    echo -e "${GREEN}'$file_path' moved to recycle bin as ${NC}${YELLOW}'$new_name'${NC}"

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
    # Usar variável de ambiente para sorting, default é "date"        
    local max_size_mb=$(grep "^MAX_SIZE_MB=" "$CONFIG_FILE" | cut -d '=' -f2)
    max_size_bytes=$((max_size_mb * 1024 * 1024))
    local sort_by="${RECYCLE_BIN_SORT_BY:-date}"
    local display_path
    local display_name

    echo "=== Recycle Bin Contents ==="

    if [ ! -f "$METADATA_FILE" ] || [ ! -s "$METADATA_FILE" ]; then
        echo "Recycle bin is empty"
        return 0
    fi

    local total_items=$(($(wc -l < "$METADATA_FILE") - 2))  #total de linhas - 1 (do header)

    if [ "$total_items" -eq 0 ]; then
        echo "Recycle bin is empty"
        return 0
    fi

    # Print header
    printf "%-20s %-20s %-50s %-25s %-13s\n" "ID" "NAME" "ORIGINAL PATH" "DELETION DATE" "SIZE"
    printf "%-20s %-20s %-50s %-25s %-13s\n" "--" "----" "------------" "-------------" "----"

    # Calcular total_size ANTES do loop
    local total_size=$(tail -n +2 "$METADATA_FILE" | awk -F',' '{sum += $5} END {print sum+0}')
    
    
    # ORDENAÇÃO baseada na variável de ambiente
    case "$sort_by" in
        "name")
            tail -n +2 "$METADATA_FILE" | sort -t',' -k2 ;;
        "size")
            tail -n +2 "$METADATA_FILE" | sort -t',' -k5 -n ;;
        "date"|*)
            tail -n +2 "$METADATA_FILE" | sort -t',' -k4 ;;
    esac | while IFS=',' read -r id name path deletion_date size type permissions owner; do
      if [[ "$id" =~ ^# || -z "$id" || "$id" == "ID" ]]; then
        continue
      fi
        # remove os espacos tr -d
        id=$(echo "$id" | tr -d ' ')
        name=$(echo "$name" )
        path=$(echo "$path" | tr -d ' ')
        deletion_date=$(echo "$deletion_date")
        size=$(echo "$size" | tr -d ' ')

        if ! [[ "$size" =~ ^[0-9]+$ ]]; then
          continue  
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

        if [ ${#name} -gt 18 ];then
          display_name="${name:0:18}.."
          else
          display_name="$name"
        fi
        
        if [ ${#path} -gt 48 ]; then
        display_path="${path:10:48}.."
        else
        display_path="$path"
        fi

        printf "%-20s %-20s %-50s %-25s %-13s\n\n" "$id" "$display_name" "$display_path" "$deletion_date" "$size_human"
    done
    
    echo ""
    echo "Total items: $total_items"
    
    # formatar o total_size também para humano
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
    if [[ $usage_percent > 100 ]]; then
      echo "Usage above the limit, consider using auto_cleanup to erase old files"
      fi
    echo ""
    echo "To change sorting, use:"
    echo "  export RECYCLE_BIN_SORT_BY=name    # Sort by name"
    echo "  export RECYCLE_BIN_SORT_BY=size    # Sort by size" 
    echo "  export RECYCLE_BIN_SORT_BY=date    # Sort by date (default)"
    
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
    
    echo "=== DEBUG RESTORE ==="
    echo "Searching for: '$search_term'"
    
    if [ -z "$search_term" ]; then
        echo -e "${RED}Error: No file ID or filename specified${NC}"
        return 1
    fi

    # Verificar se o metadata file existe
    if [ ! -f "$METADATA_FILE" ]; then
        echo -e "${RED}Error: Recycle bin is not initialized${NC}"
        return 1
    fi

    if [ ! -s "$METADATA_FILE" ]; then
        echo -e "${RED}Error: Recycle bin is empty${NC}"
        return 1
    fi

    # MOSTRAR TODAS AS ENTRADAS DISPONÍVEIS
    echo "=== ALL MATCHING FILES IN RECYCLE BIN ==="
    echo "Metadata file: $METADATA_FILE"
    echo ""    
    # Procurar de forma mais flexível
    local metadata_entry
    metadata_entry=$(awk -F ',' -v term="$search_term" '
    tolower($1) == tolower(term) || tolower($2) == tolower(term)' "$METADATA_FILE")
    
    if [ -z "$metadata_entry" ]; then
        echo -e "${RED}Error: No file found matching '$search_term'${NC}"
        echo ""
        echo "Tips:"
        echo "• Use './recycle_bin.sh list' to see all files"
        echo "• Use the exact ID from the list above"
        echo "• Or use part of the filename"
        return 1
    fi
    
    echo "Found entries:"
    echo "$metadata_entry"
    echo ""
    
    # Se encontrar múltiplas entradas, usar a primeira
    if [ $(echo "$metadata_entry" | wc -l) -gt 1 ]; then
        echo -e "${YELLOW}Multiple files found. Using the first one.${NC}"
        metadata_entry=$(echo "$metadata_entry" | head -n 1)
    fi
    
    echo -e "Using entry: ${GREEN}$metadata_entry${NC}"
    echo ""

    # Parse metadata fields
    local id original_name original_path deletion_date file_size file_type permissions owner
    IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$metadata_entry"
    
    # Clean up fields
    file_type=$(echo "$file_type" | sed 's/^"//;s/"$//')
    original_name=$(echo "$original_name" )
    original_path=$(echo "$original_path" )
    id=$(echo "$id" | tr -d '[:space:]')

    echo "File details:"
    echo "• ID: $id"
    echo "• Name: $original_name"
    echo "• Original path: $original_path"
    echo "• Deleted: $deletion_date"
    echo "• Size: $file_size bytes"
    echo "• Permissions: $permissions"
    echo ""

    
     # Find the actual file in recycle bin (allow regular files and symbolic links)
    local recycled_file
    recycled_file=$(find "$FILES_DIR" -name "*_${id}" \( -type f -o -type l \) 2>/dev/null | head -n 1)
    
    if [ -z "$recycled_file" ]; then
        echo -e "${RED}Error: Physical file not found in recycle bin${NC}"
        echo "Looking for pattern: '*_${id}'"
        echo "Files in recycle bin:"
        search_recycled "*_${id}"
        return 1
    fi

    echo "Physical file found: $recycled_file"
    echo ""

    # Check if original directory exists
    local original_dir
    original_dir=$(dirname "$original_path")
    
    if [ ! -d "$original_dir" ]; then
        echo -e "${YELLOW}Warning: Original directory '$original_dir' no longer exists${NC}"
        read -p "Create directory? [y/N]: " create_dir
        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
            if ! mkdir -p "$original_dir" 2>/dev/null; then
                echo -e "${RED}Error: Failed to create directory '$original_dir'${NC}"
                return 1
            fi
            echo -e "${GREEN}Directory created successfully${NC}"
        else
            echo "Restoration cancelled"
            return 1
        fi
    fi

    # Handle file existence conflicts
    local final_destination="$original_path"
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
                    if ! rm -f "$original_path" 2>/dev/null; then
                        echo -e "${RED}Error: Cannot overwrite file. Permission denied.${NC}"
                        return 1
                    fi
                    echo "Overwriting existing file..."
                    ;;
                2)
                    local timestamp
                    timestamp=$(date +%Y%m%d_%H%M%S)
                    local base_name
                    base_name=$(basename "$original_path")
                    local extension=""
                    
                    # Handle files with extensions
                    if [[ "$base_name" =~ ^(.+)\.([^.]+)$ ]]; then
                        base_name="${BASH_REMATCH[1]}"
                        extension=".${BASH_REMATCH[2]}"
                    fi
                    
                    final_destination="$(dirname "$original_path")/${base_name}_restored_${timestamp}${extension}"
                    echo "Will restore as: $(basename "$final_destination")"
                    ;;
                3)
                    echo "Restoration cancelled"
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
        return 1
    fi

    # Restore original permissions
    if [ -n "$permissions" ] && [[ "$permissions" =~ ^[0-7]+$ ]]; then
        if chmod "$permissions" "$final_destination" 2>/dev/null; then
            echo -e "${GREEN}Permissions restored to $permissions${NC}"
        else
            echo -e "${YELLOW}Warning: Could not restore permissions (may require root)${NC}"
        fi
    fi

    # Remove entry from metadata
    local temp_file
    temp_file=$(mktemp)
    if grep -v "^$id," "$METADATA_FILE" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$METADATA_FILE"
        echo -e "${GREEN}Metadata updated${NC}"
    else
        echo -e "${YELLOW}Warning: Could not update metadata file${NC}"
        rm -f "$temp_file"
    fi

    # Log the restoration
    local log_entry
    log_entry="$(date '+%Y-%m-%d %H:%M:%S') - RESTORED: $original_name from $id to $final_destination"
    echo "$log_entry" >> "$RECYCLE_BIN_DIR/restoration.log"
    
    echo -e "${GREEN}File successfully restored to: $final_destination${NC}"
    echo "Restoration completed and logged"

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
  local deletionFile="$1" 
  local index=1
  
  matches=()

  if [[ -z "$deletionFile" ]];then #Checks for arguments. If it doesn't have any args it will ask to delete everything.
  echo "Are you sure? Type yes to erase all the files. "
  read  -r REPLY
    if [[ "$REPLY" == "yes" ]]; then
  for  file in $FILES_DIR/*; do
    rm -rf $file
  done
  echo "All files have been deleted. "
  echo "# Recycle Bin Metadata" > "$METADATA_FILE"
  echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"
  else 
  echo "Operation canceled. Exiting... "
  exit 1
  fi

  else

  while IFS=',' read -r id name path date size type perms owner; do
  matches+=("$id,$name,$path,$date,$size,$type,$perms,$owner")
    echo "[$index] ID: $id | Name: $name | Deleted on: $date | Size: ${size}B | Type: $type"
    ((index++))
  done < <(grep ",$deletionFile," "$METADATA_FILE" )

   if [ "${#matches[@]}" -eq 0 ]; then
      echo "No matching files found."
      return 1
    fi

  echo "Choose the index of the file you want to delete. Anything else to cancel. "
  read -r selection

  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#matches[@]}" ]; then
    echo "Invalid selection."
    return 1
  fi

  selected="${matches[$((selection-1))]}"
  IFS=',' read -r id name path date size type perms owner <<< "$selected"
    
  local full_name="${name}_${id}"
  local full_path="$FILES_DIR/$full_name"
  if [ -e "$full_path" ]; then
    rm -rf "$full_path"
    grep -v "$id" "$METADATA_FILE" > "$METADATA_FILE.tmp" && mv "$METADATA_FILE.tmp" "$METADATA_FILE" 
  fi
  echo "The file : "$deletionFile" with the ID: "${id}", has been deleted. "
  return 1
  fi
 

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
  shopt -s nocasematch
  # TODO: Implement this function
  local pattern="$1"
  matches=()
  local found=0

  if [[ -z "$pattern" ]];then #Checks for arguments. If it doesn't have any args it will ask to delete everything.
  echo "No pattern or name. "
  return 1
  fi

  if [[ "$pattern" == \*.* ]]; then
    local extension="${pattern#*.}"  
      while IFS=',' read -r id name path date size type perms owner; do
      local regex="\.${extension}$"
      if [[ "$name" =~ $regex ]]; then  
        echo "ID: $id | Name: $name | Deleted on: $date | Original Path: ${path} | Type: $type"     
        found=1
        fi    
    done < <(tail -n +3 "$METADATA_FILE" )
  else
      while IFS=',' read -r id name path date size type perms owner; do
      if [[ "$name" =~ $pattern || "$path" =~ $pattern ]]; then  
        echo "ID: $id | Name: $name | Deleted on: $date | Original Path: ${path} | Type: $type"     
        found=1
        fi    
    done < <(tail -n +3 "$METADATA_FILE" )
  fi

    if [[ "$found" -eq 0 ]]; then
      echo "No matching files found."
      return 1
    fi
  
  # Your code here
  # Hint: Use grep to search metadata

  return 0
}
#################################################
# Function: auto_cleanup
# Description: Erases files before a determined date.
# Parameters: None
# Returns: 0
#################################################

auto_cleanup(){
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "No config file found. Skipping auto-cleanup."
    return 1
  fi

  local cleanup_days
  cleanup_days=$(grep "^AUTO_CLEANUP_DAYS=" "$CONFIG_FILE"| cut -d '=' -f2) 
  
  if ! [[ "$cleanup_days" =~ ^[0-9]+$ ]]; then
    echo "Invalid AUTO_CLEANUP_DAYS value. "
    return 1
  
  fi
  
    local present_date
    present_date=$(date +%s)
    local deleted_ids=()

    while IFS=',' read -r id name path date size type perms owner; do
      if ! deletion_date=$(date -d "$date" +%s 2>/dev/null); then
        echo "Skipping entry with invalid date: $date"
        continue
      fi
        
      age_days=$(( (present_date - deletion_date) / 86400 ))
      if [[ $age_days -ge $cleanup_days ]]; then
        file_path="$FILES_DIR/${name}_${id}"
        if [ -e "$file_path" ]; then
          echo "The file : "$name" with the ID: "${id}", has been deleted. " 
          deleted_ids+=("$id")
          if [ -d "$file_path" ]; then
            rmdir "$file_path" 2>/dev/null || rm -rf "$file_path"
          else
            rm -f "$file_path"
          fi
        fi    
      fi
    done < <(tail -n +3 "$METADATA_FILE" )

    if [ "${#deleted_ids[@]}" -gt 0 ]; then
    grep -v -E "^(${deleted_ids[*]// /|})," "$METADATA_FILE" > "$METADATA_FILE.tmp" && mv "$METADATA_FILE.tmp" "$METADATA_FILE"
    fi

    

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
    return 0
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
    $0 [OPTION] [ARGUMENTS]

OPTIONS:
    delete <file>  | delete <file> <file> ...  Move file(s)/directory to recycle bin
    list             List all items in recycle bin
    restore <name or ID >     Restore file by name or ID. 
    search <pattern> Search for files by name
    empty            Empty recycle bin permanently
    empty <name>     Shows a list of matching files (if there is any) and asks for a second
                     index input to choose which to delete. 
    help             Display this help message
    auto             Remove files inside the trash bin older than the chosen amount of days. Beware the default is 30 days!!!
    
EXAMPLES:

    $0 delete myfile.txt
    $0 list
    $0 restore 1696234567_abc123
    $0 search "*.pdf"
    $0 empty
    
    $0 empty "test.txt"
    

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