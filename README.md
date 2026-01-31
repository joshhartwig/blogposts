# Blog Posts

This repository contains the blog posts for [joshbuildstuff.com](https://joshbuildstuff.com)
  
All blog post files are located in the `/posts/{slug}` directory.

- `create_default_post`: A script to generate a new markdown file with a default template for a blog post.
- `rename_md_files.sh`: A script to batch-rename markdown files, typically to enforce a consistent naming convention.

## Version History

1.0: Initial commit, each post is under the posts directory. The containerized Go app will mount the posts directory and then reach each .md file.
1.01: Updated to support folder per post structure to support images colocated with markdown posts, fixed shell script to ensure new posts are created as 'draft' = true
