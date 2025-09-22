#!/bin/bash

# to mb
to_megabytes() {
    local value=$1

    value=$(echo "$value" | tr -d ' ')
    
    local num=$(echo "$value" | grep -oE '^[0-9]+(\.[0-9]+)?')
    local unit=$(echo "$value" | grep -oE '[a-zA-Z]+$' | tr '[:upper:]' '[:lower:]')
    
    case $unit in
        "k"|"kb") echo "$num / 1024" | bc -l ;;
        "m"|"mb") echo "$num" ;;
        "g"|"gb") echo "$num * 1024" | bc -l ;;
        "t"|"tb") echo "$num * 1024 * 1024" | bc -l ;;
        *) echo "$num" ;; 
    esac
}

if [ $# -ne 4 ]; then
    echo "Usage: <path_to_log_dir> <limit> <N> <M>"
    echo "Limit can be in KB, MB, GB, TB (e.g., 1G, 500M, 2.5GB)"
    exit 1
fi

DIR="$1"
LIMIT_INPUT="$2"
N="$3"
M="$4"


LIMIT_MB=$(to_megabytes "$LIMIT_INPUT")

LIMIT_MB=$(printf "%.0f" "$LIMIT_MB")

echo "Original limit: $LIMIT_INPUT"
echo "Limit in MB: $LIMIT_MB MB"

while true; do
    if [ ! -d "$DIR" ]; then
        read -p "ENTER CORRECT PATH: " DIR
    
        if [ -z "$DIR" ]; then
            echo "Operation cancelled."
            exit 1
        fi
    else
        break
    fi
done

size=$(du -sm "$DIR" | cut -f1)

if [ "$LIMIT_MB" -eq 0 ]; then
    echo "Error: Limit cannot be zero"
    exit 1
fi

ratio=$((size * 100 / LIMIT_MB)) 
echo "Current size: $size MB"
echo "Limit: $LIMIT_MB MB"
echo "Fill ratio: $ratio%"

BACKUP_DIR="${DIR}/backup"
mkdir -p "$BACKUP_DIR"  

if [ $ratio -gt $N ]; then
    echo "WARNING: Usage exceeds $N% limit! Archiving $M oldest files..."
    
    file_list=$(mktemp)
    
    find "$DIR" -maxdepth 4 -type f -not -path "$BACKUP_DIR/*" -printf '%T@ %p\0' | \
    sort -zn | head -zn $M | cut -zd' ' -f2- > "$file_list"
    
    if [ ! -s "$file_list" ]; then
        echo "No files found to archive."
        rm -f "$file_list"
        exit 0
    fi
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    archive_name="${BACKUP_DIR}/backup_${timestamp}.tar.gz"

    echo "Archiving files:"
    
    while IFS= read -r -d '' file; do
        echo "$file"
    done < "$file_list"
    
    tar -czf "$archive_name" --null -T "$file_list"
    
    if [ $? -eq 0 ]; then
        echo "Archive created successfully: $archive_name"
        echo "Archive size: $(du -h "$archive_name" | cut -f1)"
        
        echo "Removing original files..."
        while IFS= read -r -d '' file; do
            rm -f "$file"
        done < "$file_list"
        echo "Original files removed."
        
        rm -f "$file_list"
        
        new_size=$(du -sm "$DIR" | cut -f1)
        new_percent=$((new_size * 100 / LIMIT_MB))
        echo "New size: $new_size MB ($new_percent%)"
    else
        echo "Error creating archive!"
        rm -f "$file_list"
        exit 1
    fi
else
    echo "Usage is within limits. No action needed."
fi