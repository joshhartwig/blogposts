#!/bin/bash

DATE="2026-1-18"
SLUG="default-post-${DATE}"
FOLDER="$SLUG"
FILENAME="${FOLDER}/${SLUG}.md"

mkdir -p "$FOLDER"

cat > "$FILENAME" <<EOF
---
title: "New Post"
date: ${DATE}
summary: "Fill me in with a brief summary of the post."
draft: true
tags:
  - "#Go"
  - "#Development"
  - "DevOps"
---

# Heading Example

This is a paragraph. You can write your blog content here.

## Subheading Example

- Bullet point one
- Bullet point two

**Bold text** and *italic text*.

\`\`\`go
// Code block example
fmt.Println("Hello, world!")
\`\`\`
EOF

echo "Created $FOLDER/ with $FILENAME"