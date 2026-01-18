#!/bin/bash

DATE="2026-1-18"

for file in *.md; do
  # Skip if no .md files are found
  [ -e "$file" ] || continue

  # Remove extension, convert to lowercase, replace spaces/underscores with dashes
  base=$(basename "$file" .md)
  newbase=$(echo "$base" | tr '[:upper:]' '[:lower:]' | tr ' _' '-')
  newname="${newbase}-${DATE}.md"

  # Rename the file
  mv "$file" "$newname"
  echo "Renamed $file -> $newname"
done