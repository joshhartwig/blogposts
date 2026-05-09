# Blog Posts

This repository contains the blog posts and configuration for [joshbuildstuff.com](https://joshbuildstuff.com)
  
All blog post files are located in the `/posts/{slug}` directory.

- `create_default_post`: A script to generate a new markdown file with a default template for a blog post.
- `rename_md_files.sh`: A script to batch-rename markdown files, typically to enforce a consistent naming convention.

Site configuration is stored in `/config/config.toml`, the settings control various functionality for the [blog](https://github.com/joshhartwig/blogo) example below.

```toml
site_title = "Josh Build Stuff" 
base_url = "https://joshbuildstuff.com"
theme = "default"
posts_per_page = 5
content_dir = "/content"

[author]
name = "Josh Hartwig"
bio = "An unserious blog..."
```

The settings are mostly self explanatory. The theme and content directory are intended to be mounted by the docker container for the blog.

## Version History

1.0: Initial commit, each post is under the posts directory. The containerized Go app will mount the posts directory and then reach each .md file.
1.01: Updated to support folder per post structure to support images colocated with markdown posts, fixed shell script to ensure new posts are created as 'draft' = true. Changed each post to index to support folder per post.
1.02: Updated folder structure to include `theme` and `config` folders. `config.toml` contains site configuration to support a larger refactor of the project.
