#!/bin/bash
# rename.sh - add a prefix to every .txt file in a directory
# Usage: rename.sh <directory> <prefix>
dir="$1"
prefix="$2"

if [ "$#" -lt 2 ]; then
    echo "Usage: rename.sh <directory> <prefix>"
    exit 1
fi

if [ ! -d "$dir" ]; then
    echo "Error: $dir is not a directory"
    exit 1
fi

for f in "$dir"/*.txt; do
    name=$(basename "$f")
    mv "$f" "$dir/$prefix$name"
    echo "Renamed: $name -> $prefix$name"
done
