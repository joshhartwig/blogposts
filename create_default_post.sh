#!/bin/bash

DATE="2026-1-18"
FILENAME="default-post-${DATE}.md"

cat > "$FILENAME" <<EOF
---
title: "Automating Deployment with Docker, Containers and Github Actions"
date: ${DATE}
summary: "We have built this blog but lets make it easy to deploy on a VPS, Linux server or even another development box. We are going to containerize the blog, create a Docker Compose to test locally and then create a github action that updates the container registry on every push to main"
draft: false
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

echo "Created $FILENAME"