#!/bin/bash

if [ $# -ne 4 ]; then
    echo "Usage: <path_to_log_dir> <limit> <N> <M>"
    exit 1
fi

DIR="$1"
LIMIT="$2"
N="$3"
M="$4"

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
echo "Raw size: ${size}M"
echo "Limit: ${LIMIT}M"

if [ "$LIMIT" -eq 0 ]; then
    echo "Error: Limit cannot be zero"
    exit 1
fi

ratio=$((size * 100 / LIMIT)) 
echo "Fill ratio: $ratio%"

echo "$DIR $LIMIT $N $M $size MB ($ratio% of limit)"

BACKUP_DIR="${DIR}/backup"
mkdir -p "$BACKUP_DIR"  

if [ $ratio -gt $N ]; then
    echo "WARNING: Usage exceeds $N% limit! Archiving $M oldest files..."
    
    file_list=$(mktemp)
    
    find "$DIR" -maxdepth 1 -type f -not -path "$BACKUP_DIR/*" -printf '%T@ %p\0' | \
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
        new_percent=$((new_size * 100 / LIMIT))
        echo "New size: $new_size MB ($new_percent%)"
    else
        echo "Error creating archive!"
        rm -f "$file_list"
        exit 1
    fi
else
    echo "Usage is within limits. No action needed."
fi