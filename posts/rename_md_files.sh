#!/bin/bash

DATE="2026-1-18"

for dir in */; do
  # Skip if no directories are found
  [ -d "$dir" ] || continue

  # Remove trailing slash
  dirname="${dir%/}"

  # Find the .md file in the directory
  mdfile=$(find "$dirname" -maxdepth 1 -name "*.md" -type f | head -1)
  [ -n "$mdfile" ] || continue

  # Get base name without extension
  base=$(basename "$mdfile" .md)

  # Convert to lowercase, replace spaces/underscores with dashes
  newslug=$(echo "$base" | tr '[:upper:]' '[:lower:]' | tr ' _' '-')
  newslug="${newslug%-${DATE}}-${DATE}"

  # Skip if already correctly named
  [ "$dirname" = "$newslug" ] && continue

  # Rename folder and file
  mv "$dirname" "$newslug"
  if [ -f "$newslug/$base.md" ]; then
    mv "$newslug/$base.md" "$newslug/$newslug.md"
  fi

  echo "Renamed $dirname/ -> $newslug/"
done
