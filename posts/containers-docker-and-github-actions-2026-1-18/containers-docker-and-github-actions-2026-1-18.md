---
title: "Automating Deployment with Docker, Containers and Github Actions"
date: 2026-1-18
summary: "We have built this blog, but let's make it easy to deploy on a VPS, Linux server, or even another development box. We are going to containerize the blog, create a Docker Compose file to test locally, and then create a GitHub Action that updates the container registry on every push to main."
draft: false
tags:
  - "#Go"
  - "#Development"
  - "DevOps"
---

This is a continuation of the previous series of posts here:

[Part 1](https://joshbuildstuff.com/posts/building-a-blog-in-go-part-1-2026-1-18)
[Part 2](https://joshbuildstuff.com/posts/building-a-blog-in-go-part-2-2026-1-18)
[Part 3](https://joshbuildstuff.com/posts/building-a-blog-in-go-part-3-2026-1-18)
[Part 4](https://joshbuildstuff.com/posts/building-a-blog-in-go-part-4-2026-1-18)

That being said, you certainly do not need to do all the previous parts for this post to be beneficial. This part can apply to any sort of project but may require some tweaks if you are using another language. With that said...

Time to make this easy to deploy

We put in all the time and effort to build this thing, so why not take a little bit more time and effort to make it easy to deploy? In this post, we are going to turn this project into a 'distroless' Docker container, make sure it works locally, then create a pipeline that ensures all commits to main are replicated to our Docker image in the GitHub Container Registry. The end result is that you can create a Docker Compose file on any type of server and have your container running locally within 30 seconds. Sound good? Let's get going.

Let's start by creating a new Dockerfile.

```bash
touch Dockerfile
```

Now copy the following into the `Dockerfile`:

```Dockerfile
# ---- build stage ----
FROM golang:1.24.2 AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG TARGETOS
ARG TARGETARCH

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
  go build -trimpath -ldflags="-s -w" -o /out/blogo ./cmd/server

# ---- runtime stage ----
FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app

COPY --from=build /out/blogo /app/blogo


# No need to copy ui/static or ui/templates, as they are embedded in the binary

# Optional: bake default content too (handy for first run)
COPY content /app/content

EXPOSE 3999
USER nonroot:nonroot

ENTRYPOINT ["/app/blogo"]
```

Let's explain what this does... The Dockerfile has two stages:

1. Build Stage

* Uses the official Go image to compile your Go app.
* Sets up a working directory.
* Downloads dependencies (`go mod download`).
* Copies your code into the container.
* Builds your Go app for the target OS and architecture, outputting a binary called 'blogo'.

1. Runtime Stage

* Uses a minimal, secure “distroless” image (no shell or package manager).
* Sets up a working directory.
* Copies the compiled blogo binary from the build stage.
* Optionally copies default content for the app.
* Exposes port 3999 for your app.
* Runs the app as a non-root user for security.
* Starts the app with the ENTRYPOINT.

At this point, we are able to build a container.

Let's now create a `docker-compose.yaml` file that makes it easy for us to spin up the container and test that it is working.

```sh
touch docker-compose.yaml
```

Paste this text into the `docker-compose.yaml` file

```bash
services:
  blog:
    build: .
    container_name: blog
    restart: unless-stopped
    ports:
      - "5040:3999"
```

This Docker Compose file does the following:

* Creates a new service called `blog`
* Runs the build command
* Ensures that the blog will restart unless we stop it
* Maps port 5040 on the outside to 3999 on the inside of the container

It is worth noting that you can also set this to `3999:3999` as well. You would need to ensure you don't fire up your development server while your container is running. Ultimately, do whatever works best for you.

Let's also create a `.dockerignore` file. This will ensure our images are smaller and keep out the junk.

```bash
touch .dockerignore
```

Add the following (make it apply to your project):

```text
# Git
.git
.gitignore

# OS junk
.DS_Store
Thumbs.db

# Editors
.vscode
.idea

# Go build artifacts
bin/
dist/
*.exe
*.out
*.test

# Air live reload
.air.toml
tmp/

# Logs
*.log

# Node (if present anywhere)
node_modules/

# Docker leftovers
docker-compose.override.yml

# Env / secrets
.env
.env.*
```

With both the `Dockerfile` and the `docker-compose.yaml` in place, let's try to build the container (note this assumes you have Docker installed on your system). Run the following commands:

```bash
docker build -t blog:local . #this may take a bit
docker compose up -d # start the compose file and disconnect
```

If everything functioned properly, we should have a working container. If your server is running on the same port defined in your `docker-compose.yaml`, you need to stop it. To see if your server is running, run the following command:

```bash
docker ps -a # should show all running containers (may require sudo)
```

## Github Actions

At this point, we should push our changes to the repo. The end goal here is to get all changes that we make to the blog to be reflected in our container image. There are a few ways to do this, but one common way is to use GitHub Actions.

Create a `.github` directory at the root of your project.

```bash
mkdir -p .github .github/workflows
touch .github/workflows/publish.yml
```

Copy the following text into that yaml file

```yaml
name: Build & Push Image to GHCR

on:
  push:
    branches: ["main"]

permissions:
  contents: read
  packages: write

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push (multi-arch)
        uses: docker/build-push-action@v6
        with:
          context: .
          file: Dockerfile
          push: true
          platforms: linux/amd64,linux/arm64
          tags: |
            ghcr.io/${{ github.repository }}:latest
            ghcr.io/${{ github.repository }}:${{ github.sha }}

```

Now let's review the `publish.yml` file and what it does:

1. Every time you push code into the main branch, it will run.
2. It will check out your code.
3. Sets up the build tools needed for Docker images for all sorts of builds.
4. Logs into GitHub Container Registry using your GitHub credentials.
5. Builds your Docker image for multiple platforms.
6. Pushes the built image to GHCR with two tags: `latest` and a unique tag for each commit.

Commit these changes up to GitHub and check the repo. You should see a green light near the title of the repo. This will show the status of the GitHub Action and if you ran into any errors. If you were successful, you should now have your container in the GitHub Container Registry.

You can now change your local `docker-compose.yml` file to reflect it being in the container registry:

```yaml
services:
  blog:
    image: ghcr.io/youraccount/blog:latest
    ports:
      - "5040:5040"
    restart: unless-stopped
```

You should now be able to deploy this project on whatever server you want, as long as it has Docker and Compose on it. Simply SSH into the server, create a new `docker-compose.yml` file, and add the contents above. Bring up the stack and you should be off to the races.

I hope you enjoyed!
