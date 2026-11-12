#!/bin/bash
# backup.sh - archive a directory into ~/backups with a timestamp
# Usage: backup.sh <directory>
src="$1"

if [ -z "$src" ]; then
    echo "Usage: backup.sh <directory>"
    exit 1
fi

if [ ! -d "$src" ]; then
    echo "Error: $src is not a directory"
    exit 1
fi

mkdir -p ~/backups
name=backup-$(date +%Y%m%d-%H%M%S).tar.gz
tar -czf ~/backups/$name "$src"
echo "Backup created: ~/backups/$name"
