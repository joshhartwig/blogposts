---
title: "Building a blog in Go Part 1"
date: 2025-11-15
summary: "Learn how to start building a simple blog in Go by setting up a basic HTTP server, reading markdown files, and structuring your project for future development."
draft: false
tags:
  - "#Go"
  - "#Development"
---


Let's build a blog!

Why a blog? It may sound boring and simple, but when the rubber meets the road, most things are. Complex systems are usually just many simple systems stitched together. I learn best by creating things I would actually use, and what we're building in this series is the same software that runs this blog.

So, what can you learn by building a blog? Surprisingly, quite a lot. Just off the top of my head:

* Serving HTTP / Servers
* Routing
* HTML templates
* Serving Markdown
* Data Structures
* Working with file systems

Note: This guide assumes some basic experience with Go. We'll start slow and move quicker as we work through the basics.

Let's talk in a little more detail about the architecture of this blog. First, we'll get a simple web server running and set up some basic routing and handlers. Then, we'll lay the groundwork for reading markdown files at startup, and finally, we'll put together some templates and render our markdown. A word of warning: don't expect to take this to production—we want a minimum viable product here.

Now, let's get going!

1. Open the terminal, create a new directory, `cd` into it, initialize it with `go mod init`, and create a new `main.go` file.

```bash
mkdir example_blog && cd example_blog && go mod init github.com/yourname/exampleblog && touch main.go
```

1. Open the folder in VS Code or your code editor of choice (this assumes you have `code` set up to open via `code .`).

```bash
code .
```

1. Open `main.go` and add the following:

```go
package main

import "fmt"

func main() {
 fmt.Println("hello world")
}
```

1. Open the integrated terminal in the code editor or bring up a terminal in the same folder and run:

```bash
go run .
```

You should see `hello world` printed in the terminal.

Now, let's move a little quicker and get the basics of a server going. Add the content below to your main function and run it.

```go
import (
 "fmt"
 "net/http"
)

func main() {
 http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
  w.Write([]byte("hello world"))
 })

 if err := http.ListenAndServe(":5040", nil); err != nil {
  fmt.Printf("server crashed with error %v", err)
 }
}
```

We now have a very basic HTTP server that writes `hello world` on port 5040. The code above registers a handler for the `/` route and responds with "hello world". We use the parameter `w` to write and `r` to interact with our HTTP requests.

Go ahead and test it in your browser or via terminal with `curl`.

```bash
curl http://localhost:5040/
# hello world
```

Let's think about what we need to build the start of a blog. We can deliver some content to a browser at this point, but it's not very useful. Let's work on reading the markdown files.

Create a `content` folder in the terminal or in the code editor and add this file and its content.

```markdown
<!-- firstpost.md -->
# Hello World

This is a first post! There are many others but this is mine.
```

Now would be a good time to talk about the structure of this project. For our initial iteration, we are going to serve very basic HTML at the default route `/` and list out our posts that are read from the content directory. Each post will render a link, and clicking the link will take you to `/posts/{slug}` with the post name being the slug.

## Reading Markdown Content

At the start of the application, we need to read all the markdown files into memory and serve them up to our router. Before we start down that path, let's create a few structs: one to store server-related configuration data and another to store data for our actual markdown post. At the top of the `main.go` file, create the following:

```go
// Stores configuration data for our app at startup
type config struct {
 port int
 path string
}

// We will pass data into our homepage with this struct
type HomePageData struct {
 Title string
 Urls  []string
}

// This struct contains data related to the post
type PostPageData struct {
 Title   string
 Content template.HTML
}
```

Let's populate our configuration struct with some useful data like our port and content paths. Ideally, we don't want to hardcode this type of data into our main function. This 'configuration' structure is a fairly common pattern in use.

Add these lines to the top of our main function

```go
var cfg config

// assign the passed in parameter as the port & path 
flag.IntVar(&cfg.port, "port", 5040, "port to listen on")
flag.StringVar(&cfg.path, "content-path", "./content", "path to markdown content")
flag.Parse() // don't forget to parse the values
```

We will create a variable for a config struct and assign values to it at the start of the main function. The `flag` package provides some useful functions to parse command line options. Both `IntVar` and `StringVar` functions parse command line options at runtime into our struct fields. If you do not pass any command line options, the defaults will be used. This actually presents a little bit of a problem with our port variable that we need to fix.

Take a look at this line

```go
// use the default serve mux to start a server on port 5040 and check for errors
 if err := http.ListenAndServe(":5040", nil); err != nil {
  fmt.Printf("server crashed with error %v", err)
 }
```

Ideally, we would just add `cfg.port` to the first parameter of `ListenAndServe`. Can you spot the issue? Let's try... Make the following change.

```go
if err := http.ListenAndServe(cfg.port, nil); err != nil {
  fmt.Printf("server crashed with error %v", err)
 }
```

Your editor should give you a squiggly line or error out when you try to run the program. The issue is that you are assigning an integer to a function that expects a string. Even converting this to a string won't fix the issue entirely, as it expects a string like this `:port`. Let's convert the port to a string using the `fmt.Sprintf` function. Make the following change to the function call:

```go
http.ListenAndServe(fmt.Sprintf(":%d", cfg.port), nil)
```

The `Sprintf` function will format the variable for us and return a string. We are basically telling the function to return a string with the colon at the start and replace the `%d` with the integer variable.

Let's parse those markdown files. Create a function with this name and signature:

```go
readMarkdown(fSys fs.FS) (map[string][]byte, error)
```

 right under the main function.

`readMarkdown()` just takes a single parameter, the `fs.FS` interface. The `fs.FS` interface is an abstraction that allows us to plug in various different implementations of the filesystem. If that sounds confusing, don't worry about it for now. One thing to remember is that leveraging these interfaces makes the functions easier to test.

Let's continue on...

We will start by creating a "cache": `cache := make(map[string][]byte)`. This creates a map that will hold our slugs by name and our markdown data. We will then return this data later.

Why use a map instead of a slice or array? Using a `map` data structure allows for constant-time lookup of an entity, versus having to loop through elements.

So, we have our cache. Now let's get our files. Add the following lines:

```go
files, err := fs.Glob(fSys, "*.md") // read all .md files from the file system
 if err != nil {
  return nil, err
 }
```

We are using `fs.Glob` to return a slice of strings of the files that match the extension passed into the function `*.md`. Now let's iterate through these files, read them, and store them in our cache.

```go
// iterate through each of the markdown files and read the content into a []byte
 for _, f := range files {
  data, err := fs.ReadFile(fSys, f)
  if err != nil {
   return nil, err
  }

  cache[strings.TrimSuffix(f, ".md")] = data
 }
```

Here is the order of operations for the code above:

* Range over each string entry in the slice (e.g., helloworld.md)
* Use `fs.ReadFile` to read the file contents into a `[]byte`
* Lastly, assign the filename as the key in our cache along with the data

This is what `main.go` should look like now:

```go
package main

import (
 "flag"
 "fmt"
 "io/fs"
 "net/http"
 "strings"
)

type config struct {
 port int
 path string
}

type HomePageData struct {
 Title string
 Urls  []string
}

type PostPageData struct {
 Title   string
 Content template.HTML
}

func main() {
 var cfg config

 flag.IntVar(&cfg.port, "port", 5040, "port to listen on")
 flag.StringVar(&cfg.path, "content-path", "./content", "path to markdown content")
 flag.Parse()

// Register a handler function for the default route "/" and write the string "hi" in a byte slice
 http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
  w.Write([]byte("<html><body><h1>hi</h1></body></html>"))
 })

// Use the default serve mux to start a server on port 5040 and check for errors
 if err := http.ListenAndServe(fmt.Sprintf(":%d", cfg.port), nil); err != nil {
  fmt.Printf("server crashed with error %v", err)
 }
}

func readMarkdown(fSys fs.FS) (map[string][]byte, error) {
 cache := make(map[string][]byte)
 files, err := fs.Glob(fSys, "*.md") // read all .md files from the file system
 if err != nil {
  return nil, err
 }

 for _, f := range files {
  data, err := fs.ReadFile(fSys, f)
  if err != nil {
   return nil, err
  }

  cache[strings.TrimSuffix(f, ".md")] = data
 }

 return cache, nil
}
```

Time to put this in action and see if it works as expected. Go to your `main.go` file and add the following right after our calls to `flag.Parse()`:

```go
markdownCache, err := readMarkdown(os.DirFS(cfg.path))
 if err != nil {
  return
 }
 fmt.Println("cache", markdownCache)
```

We are passing in our path via `os.DirFS` and printing the results. Assuming the markdown file we created is in that directory, you should see something like this when you run the program with `go run .`:

```bash

cache map[firstpost.md:[102 105 114 115 116 112 111 115 116 46 109 100]]
```

Jackpot! It found our post and its contents are in the map. How can you tell? Because there is some data in that map.

In Part 2, we will work on rendering the content and building a router.
