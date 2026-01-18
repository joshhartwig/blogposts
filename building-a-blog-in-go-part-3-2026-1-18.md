---
title: "Building a blog in Go Part 3"
date: 2025-11-17
summary: "Part 3 covers adding basic styling to the blog, restructuring templates for maintainability, and updating the Go server to render styled content for both the homepage and individual posts."
draft: false
tags:
  - "#Go"
  - "#Development"
---

Let's recap what we have done here with parts 1 & 2. We have a server that parses markdown files, we are rendering html templates and showing each post, we are then coverting the markdown into HTML and showing that to the user. We can still improve things quite a bit.

As it stands our server starts up but you would have no idea. Let's add some code to the `main.go` file that shows what port our server is running on.

Add this line right above the call to the `listenAndServe()` function at the bottom of the `main.go`

```go
fmt.Printf("starting server on port :%d\n", cfg.port)
```

Now when we launch our server we will actually see the port that it is running on.

## Adding some style

This blog is in need of styling. I am about as far as it get from being a decent designer, I have zero creative ability and I am color blind to boot. Don't get your hopes up that this site is going to be anything special. Open up the `index.tmpl` and add the following code.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sample Blog</title>
   <style>
   body {
    font-family: 'Segoe UI', Arial, sans-serif;
    background: #18181b;
    margin: 0;
    padding: 2rem;
    color: #f3f4f6;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .container {
    display: flex;
    flex-direction: column;
    max-width: 600px;
    width: 100%;
    padding: 2.5rem 2rem;
  }
  h1 {
    font-size: 2.5rem;
    font-weight: 700;
    margin-bottom: 1.5rem;
    color: #fafafa;
  }
  p {
    font-size: 1.25rem;
    color: #e5e7eb;
    margin-bottom: 2rem;
  }
  ul {
    list-style: none;
    padding: 0;
    margin: 0 0 1rem 0;
  }
  li {
    margin-bottom: 0.75rem;
  }
  a {
    display: inline-block;
    margin-right: 1rem;
    margin-bottom: 0.5rem;
    text-decoration: none;
    color: #60a5fa;
    font-size: 1.1rem;
    transition: color 0.2s, border-bottom 0.2s;
    border-bottom: 2px solid transparent;
    font-weight: 500;
    letter-spacing: 0.02em;
  }
  a:hover {
    color: #38bdf8;
    border-bottom: 2px solid #38bdf8;
  }
  </style>
</head>
<body>
  <div class="container">
    <h1>Hi 👋</h1>
    <p>Welcome to our blog! Here you will find a collection of posts for all things interesting. I hope you enjoy!</p>
    {{ range .Urls }}
    <ul>
      <li><a href="/posts/{{.}}">{{.}}</a></li>
    </ul> 
  {{ end }}
  </div>
</body>
</html>
```

Go ahead and look at the changes, you should see something that looks a little bit better.

We have some issues now. Can you spot them? It is quite a bit more obvious now that we have a dark theme. The issue is we are not rendering a template when we go to a blog post, instead we just get some unstyled html. The reason for this is because we are simply outputting HTML from the markdown content. It is not part of our template set and not getting the styles we added.

There are a few ways to solve for this, but the easiest is to just create a structure that will likely be used for future projects.

In the terminal create two more `.tmpl` files. We will then create a template folder and move all of our templates into that folder.

```bash
touch base.tmpl post.tmpl
mkdir templates
mv *.tmpl templates/ 
mv templates/index.tmpl templates/home.tmpl
```

Now add the following content to each of the templates (note the filename of each at the top).

```html
<!-- base.tmpl -->
{{define "base"}}
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sample Blog</title>
   <style>
  </style>
</head>
<body>
  <div class="container">
    {{template "content" .}}
  </div>
</body>
</html>
{{end}}

```

```html
<!-- home.tmpl -->
{{define "content"}}
  <h1>Sample Blog</h1>
  <p>Welcome to our blog! Here you will find a collection of posts for all things interesting. I hope you enjoy!</p>
    {{ range .Urls }}
      <ul>
        <li><a href="/posts/{{.}}">{{.}}</a></li>
      </ul>
    {{end}}
{{end}}
```

```html
<!-- post.tmpl -->
{{define "content"}}
    <article class="post">
      <div class="post-body">
        {{.Content}}
      </div>
    </article>
{{end}}
```

Your folder structure and template layout should look like this.

```plaintext
project-root/
├── main.go
├── content/
│   └── hotdogs.md
    └── tacos.md
    └── icecream.md
└── templates/
  ├── base.tmpl
  ├── home.tmpl
  └── post.tmpl
```

We have made some big changes here...

We have modified our template structure to contain a base template, a home template and a post template. The home and base template will render togehter as a template set, as does the post and base template. A couple of key items to note...

* `{{define "content"}}` defines a template called content
* `{{template "content" .}}` calls a defined template called `content` and passes the `context` or `dot operator`. All of this is a fancy way to say data. We are going to pass a struct into the template.
* If you do pass a struct the fields need to be exported (upper case)
* The call to `{{.Content}}` is a call to the `Content` field in the struct (it is poorly named considering our template names)
* Template parsing order matters! You want to parse the base template first as that template calls on other templates.
* `log.Fatal()` will exit if an error is thrown. Seems appropriate considering all this app does is render markdown content.

Moving on...

We need to make some modifications to our `main.go` file as we have 3 templates and the way that each needs to be parsed. Go to `main.go` and make these changes.

```go
// create a home template set by parsing both base and home
 homeTmpl, err := template.ParseFiles(
  "templates/base.tmpl",
  "templates/home.tmpl",
 )
 if err != nil {
  log.Fatalf("failed to parse home templates: %v", err)
 }

 // create a post template set by parsing both base and post
 postTmpl, err := template.ParseFiles(
  "templates/base.tmpl",
  "templates/post.tmpl",
 )
 if err != nil {
  log.Fatalf("failed to parse post templates: %v", err)
 }
```

We are creating two template sets. Our `home` template set that generates a template out of both the `home.tmpl` and `base.tmpl` files, as well as a `post` template set generated from `post.tmpl` and `base.tmpl`. This ensures when we go to render our markdown content in the post template, we have our styling applied from the base template.

Now in our `/` route handler make these changes

```go
 // handler for default / route
 http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
  if err := homeTmpl.ExecuteTemplate(w, "base", homePageData); err != nil {
   http.Error(w, err.Error(), http.StatusInternalServerError)
  }
 })
```

Let's create a simple helper that helps create a title for our post pages. This simply takes in the slug, strips any file extensions, dashes and puts it in title case. We will use this to pass into our template's title field.

```go
func slugToTitle(slug string) string {
 slug = strings.TrimSuffix(slug, ".md") // remove the suffix
 slug = strings.ReplaceAll(slug, "-", " ") // remove dashes with spaces
 caser := cases.Title(language.AmericanEnglish) // create a caser
 return caser.String(slug) // convert to upper case
}
```

Note that the cases package is not part of the standard library. You will need to add the package with this command

```bash
go get golang.org/x/text/cases
```

And make this change in our `/post/{slug}` handler

```go
// handler for /posts/slug route
 http.HandleFunc("/posts/{slug}", func(w http.ResponseWriter, r *http.Request) {
  slug := r.PathValue("slug")
  if slug == "" {
   http.Error(w, "Post Not Found", http.StatusNotFound)
   return
  }

  data, found := markdownCache[slug]
  if !found {
   http.Error(w, "Post Not Found", http.StatusNotFound)
   return
  }

  var buf bytes.Buffer
  if err := goldmark.Convert(data, &buf); err != nil {
   log.Printf("error converting markdown for %q: %v", slug, err)
   http.Error(w, "Something went wrong rendering this post", http.StatusInternalServerError)
   return
  }

  p := PostPageData{
   Title:   slugToTitle(slug),
   Content: template.HTML(buf.String()),
  }

  // set the content type
  w.Header().Set("Content-Type", "text/html")
  if err := postTmpl.ExecuteTemplate(w, "base", p); err != nil {
   fmt.Printf("Error rendering template %v\n", err)
   return
  }
 })
```

That should be all the changes. We should have a working solution that now has our styles in both our home page and our posts. I hope these posts give you an idea of what you can do here. Some suggestions for improvement

* We have no tests, we should be testing the handlers and ensuring they render our content
* There is a ton of neat futures with Markdown parsing, stuff like Frontmatter, and code highlighting. If we added FrontMatter to these posts, it would likely break things.
* If you wanted things to be more flexible regarding styling, you could add a configuration file in json or toml and read the configuration into a struct, then direct it to various style sheets or html layouts.

I have one last post where we will do a little extra credit. We will add testing, refactor our code a little bit and add Frontmatter support.
