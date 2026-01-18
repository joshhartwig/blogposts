---
title: "Building a blog in Go Part 4"
date: 2025-11-18
summary: "This part covers refactoring the Go blog application for better testability, organizing code into handlers, routes, and helpers, and adding unit tests for core functions and HTTP handlers."
draft: false
tags:
  - "#Go"
  - "#Development"
---

Extra Credit

I did not want to leave with you hanging with no unit tests or FrontMatter parsing. Let's do some very basic testing on some of the more important functions.

In the root of our project, create a new go file named `main_test.go`.

```bash
touch main_test.go
```

I am not going to provide a ton of guidance on testing with go. If you want to learn more visit [Learn Go With Tests](https://learngowithtests.com). I will however provide you some basic tests. In your new file let's add some code.

```go
func TestReadMarkDown(t *testing.T) {
  // create a fake file system with in memory map
 fakeFS := fstest.MapFS{
  "hello-world1.md": {Data: []byte("# hi")},
  "hello-world2.md": {Data: []byte("# hola")},
 }
 
  // pass in the fake filesystem an let's see what we got back
 gotMap, err := readMarkdown(fakeFS)
 if err != nil {
  t.Errorf("error reading markdown from test %v", err)
 }
 
  // lets define what we should get
 wantMap := map[string][]byte{
  "hello-world1": []byte("# hi"),
  "hello-world2": []byte("# hola"),
 }
 
  // now compare what we should get vs what we got
 for i, wantval := range wantMap {
  gotval, found := gotMap[i]
  if !found {
   t.Errorf("error did not find %s", i)
  }

  if !bytes.Equal(wantval, gotval) {
   t.Errorf("byte values not equal %s & %s", string(wantval), string(gotval))
  }
 }
}
```

In this code, we are using some great features in Go. One of them is to the `fstest` library. This library provides all sorts of code to allow you to test your code easier. Part of the reason we passed in the `fs.FS` interface into `readMarkdown()` was to make this function easier to test. Let's give this a go, in the terminal run

 ```bash
 go test -v
 ```

The test should pass.

Let's refactor this map checking into its own standalone function. Go ahead and create a function called `equalByteMaps(a,b map[string]byte) bool` . The goal here will be to:

1. Check the length of each map, if they are not the same return false
2. Iterate through each value in a, check to see if that value exists in b
3. Compare the two values byte using `bytes.equal`

```go
func equalByteMaps(a, b map[string][]byte) bool {
 // compare lengths, ensure the same
 if len(a) != len(b) {
  return false
 }

 // iterate through each value in a
 for akey, aval := range a {
  bval, found := b[akey]
  if !found {
   return false
  }

  if !bytes.Equal(aval, bval) {
   return false
  }
 }
 return true
}
```

Now let's refactor our original test.

```go
func TestReadMarkDown(t *testing.T) {
 fakeFS := fstest.MapFS{
  "hello-world1.md": {Data: []byte("# hi")},
  "hello-world2.md": {Data: []byte("# hola")},
 }

 gotMap, err := readMarkdown(fakeFS)
 if err != nil {
  t.Errorf("error reading markdown from test %v", err)
 }

 wantMap := map[string][]byte{
  "hello-world1": []byte("# hi"),
  "hello-world2": []byte("# hola"),
 }

 if !equalByteMaps(wantMap, gotMap) {
  t.Errorf("failed map comparsion")
 }
}
```

That helped clean things up a bit and has provided us a helper function that we can reuse in the future.

Let's also tackle our handlers... if you made it this far, we have made some mistakes for the sake of simplicity. The handlers we have written are simply running out of the main function. How do you functions being called out of main? The answer here is to clean up our app a little bit and make it more testable.

Let's move our handlers out of main function. Go ahead and create two new files in the root of the project, `routes.go`, `handlers.go`, & `helpers.go`.

```bash
touch routes.go handlers.go helpers.go
```

Let's start with our `helpers.go`. With this `helpers.go` file I wanted to take a moment to clean up the overall project and have the `main()` function be as slimmer. Let's move both `readMarkdown()` and `stringToTitle()` functions from `main.go` to `helpers.go`. If that sounded confusing, just make sure `helpers.go` looks like this.

```go
package main

import (
 "io/fs"
 "strings"

 "golang.org/x/text/cases"
 "golang.org/x/text/language"
)

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

  // cache["firstpost"] = []byte("...markdown content...")
  cache[strings.TrimSuffix(f, ".md")] = data
 }

 return cache, nil
}

func slugToTitle(slug string) string {
 slug = strings.TrimSuffix(slug, ".md")
 slug = strings.ReplaceAll(slug, "-", " ")
 caser := cases.Title(language.AmericanEnglish)
 return caser.String(slug)
}
```

Next up, let introduce a new `struct` in our project called `application`. This will contain references to our cache and other dependencies and allow us to both access them and test them. At the top of `main.go` add the following just above the `config` structure.

```go
// stores a ref to our template sets
type application struct {
 templateCache map[string]*template.Template
}
// no change here, just noted for ref
type config struct {
 port int
 path string
}
```

We are going to make our handlers (which are just functions) be methods on the `application` struct.

Next go to our `handlers.go` file and add the following code.

```go
package main

import (
 "net/http"
)

func (a *application) homeHandler(w http.ResponseWriter, r *http.Request) {
 w.Write([]byte("hi"))
}

func (a *application) postHandler(w http.ResponseWriter, r *http.Request) {
 w.Write([]byte("hi"))
}
```

This `func (a *application) name` is how we implement a methond on a struct. By doing this, we are able to access everything that `application` has access to. Remember the cache we added earlier? We can now access that directly inside our handlers.

Let's modify these handlers to make them a little more useful.

```go
func (a *application) homeHandler(w http.ResponseWriter, r *http.Request) {
 // fetch our template set from our cache
 ts := a.templateCache["home"]

 // create a homepage data struct and assign a title
 pageData := HomePageData{
  Title: "Home",
 }

 // grab our post titles from our markdown cache
 for k := range a.markdownCache {
  pageData.Urls = append(pageData.Urls, k)
 }

 // execute our template with the page data
 err := ts.ExecuteTemplate(w, "base", pageData)
 if err != nil {
  http.Error(w, err.Error(), http.StatusInternalServerError)
 }
}
```

None of this should look unfamiliar, this was pretty much already in the main function. Next, let's tackle the post handler as that was a little more complicated.

```go
func (a *application) postHandler(w http.ResponseWriter, r *http.Request) {
 slug := r.PathValue("slug")
 if slug == "" {
  http.Error(w, "Post Not Found", http.StatusNotFound)
  return
 }

 // fetch our template set
 ts := a.templateCache["posts"]

 // fetch our markdown data
 data, found := a.markdownCache[slug]
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
 if err := ts.ExecuteTemplate(w, "base", p); err != nil {
  fmt.Printf("Error rendering template %v\n", err)
  return
 }
}
```

There was only a few modifications. This was for the most part copy and paste (minus a few tweaks). We have our handlers now!

Time to tackle our `routes.go` file that handles our routing to the handlers. Go ahead and add the following code to our routes file.

```go
func (a *application) routes() *http.ServeMux {
 mux := http.NewServeMux()
 
 mux.HandleFunc("/", a.homeHandler)
 mux.HandleFunc("/posts/{slug}", a.postHandler)

 return mux
}
```

Again, we are building a method off the application struct called `routes` that returns a `*http.ServeMux` . What the hell is a ServeMux you ask?

> In Go, `ServeMux` is an HTTP request multiplexer that acts as a router, directing incoming requests to the correct handler based on the URL. It matches a request's URL against a list of registered patterns and then dispatches the request to the handler that matches the most closely

It is a router, plain and simple. When we get a request to "/" we route it to our `homeHandler` function.

With all of that out of the way, we need to make some rather large changes to the `main.go` file to support all of this. Go ahead and pop open your `main.go`.

Make the following changes (if you get lost I will paste the entire main.go below)

1. Remove the handlers from our `main()` function of `main.go` file.

2. At the top of our `main()` create a variable for our application struct `var app application`

3. After the call to create a `markdownCache` go ahead and assign the `app.markdownCache = markdownCache`

   ```go
   // read our markdown files
    markdownCache, err := readMarkdown(os.DirFS(cfg.path))
    if err != nil {
     log.Fatalf("failed to read markdown files: %v", err)
     return
    }
   
    // add our markdown cache to our app
    app.markdownCache = markdownCache
   ```

4. Get rid of these lines of code

   ```go
    // create our homePageDate struct
    homePageData := HomePageData{
     Title: "Home",
    }
   
    // loop through our cache and add each url to the homePageData struct
    for k := range markdownCache {
     homePageData.Urls = append(homePageData.Urls, k)
    }
   
    // sort our urls
    sort.Strings(homePageData.Urls)
   ```

   Lastly towards the bottom of `main()` make these changes

   ```go
   app.templateCache["home"] = homeTmpl
    app.templateCache["posts"] = postTmpl
    
    // create a new instance of http.server
    srv := &http.Server{
     Addr:    fmt.Sprintf(":%d", cfg.port),
     Handler: app.routes(),
    }
   
    // start our server on our port or default to 5040
    fmt.Printf("starting server on port :%d\n", cfg.port)
   
    // use our servemux and start
    if err := srv.ListenAndServe(); err != nil {
     fmt.Printf("Server crashed with error %v\n", err)
    }
   ```

That was alot of change but it drastically cut down some of code in `main.go` and `main()`. If you are still lost regarding handlers and servemuxes, a fantastic article on handlers and servemux is this one [Alex Edwards Introduction to handlers and servemuxes in go](https://www.alexedwards.net/blog/an-introduction-to-handlers-and-servemuxes-in-go)

Here is our complete `main.go` file.

```go
package main

import (
 "flag"
 "fmt"
 "html/template"
 "log"
 "net/http"
 "os"
)

type application struct {
 templateCache map[string]*template.Template
 markdownCache map[string][]byte
}

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
 var app application

 flag.IntVar(&cfg.port, "port", 5040, "port to listen on")
 flag.StringVar(&cfg.path, "content-path", "./content", "path to markdown content")
 flag.Parse()

 // read our markdown files
 markdownCache, err := readMarkdown(os.DirFS(cfg.path))
 if err != nil {
  log.Fatalf("failed to read markdown files: %v", err)
  return
 }

 // add our markdown cache to our app
 app.markdownCache = markdownCache

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

 app.templateCache["home"] = homeTmpl
 app.templateCache["posts"] = postTmpl

 srv := &http.Server{
  Addr:    fmt.Sprintf(":%d", cfg.port),
  Handler: app.routes(),
 }

 // start our server on our port or default to 5040
 fmt.Printf("starting server on port :%d\n", cfg.port)
 // use the default serve mux to start a server on port 5040 and check for errors
 if err := srv.ListenAndServe(); err != nil {
  fmt.Printf("Server crashed with error %v\n", err)
 }
}
```

The work here we have done to refactor the app will help a bit when it comes to testing and just general orginization. Let's go ahead and try our tests and start our server to make sure everything works as intended.

```bash
go test -v ./...
go run .
```

While my test worked fine, running the app generated a panic:  `panic: assignment to entry in nil map` this is a pretty descriptive error. Let's take a look at the code, we are assigning template sets to the map before initializing it. Go ahead and add these lines

```go
app.templateCache = make(map[string]*template.Template) // create a new map
//existing code
app.templateCache["home"] = homeTmpl
app.templateCache["posts"] = postTmpl
```

After making this change our server should start up with no issues. If you are using `air` you should be in business. In the terminal we can issue this command to ensure everything is rendering correctly.

```sh
curl http://localhost:5040
```

This was my (part) of the output. The thing we want to see here is that we are rendering our template and that the data is rendering (our list of links).

```sh
<body>
  <div class="container"> 
  <h1>Hi 👋</h1>
  <p>Welcome to our blog! Here you will find a collection of posts for all things interesting. I hope you enjoy!</p>    
      <ul>
        <li><a href="/posts/hotdogs">hotdogs</a></li>
      </ul>  
      <ul>
        <li><a href="/posts/icecream">icecream</a></li>
      </ul>  
      <ul>
        <li><a href="/posts/tacos">tacos</a></li>
      </ul>
  </div>
```

We did a ton of refactoring work, but what about testing our handlers? We still need to do that. In our `main_test.go` let's add a test to ensure that our tests can hit our home handler

```go
func TestHomeHandler(t *testing.T) {
  // define a template named "base" and parse this content
 homeTmpl := template.Must(template.New("base").Parse(`
 {{define "base"}}<html><body>{{range .Urls}}<p>{{.}}</p>{{end}}</body></html>{{end}}
 `))
 
  // create an app struct and define our caches
 app := application{
  templateCache: map[string]*template.Template{"home": homeTmpl},
  markdownCache: map[string][]byte{"hello-world": {}, "second-post": {}},
 }
 
  // create a request and response
 req := httptest.NewRequest(http.MethodGet, "/", nil)
 rr := httptest.NewRecorder()
 app.homeHandler(rr, req)
 
  // ensure we get statusok
 if rr.Code != http.StatusOK {
  t.Fatalf("status = %d, want %d", rr.Code, http.StatusOK)
 }
 
  // check for hello-world rendering
 body := rr.Body.String()
 if !strings.Contains(body, "hello-world") || !strings.Contains(body, "second-post") {
  t.Fatalf("body missing urls, got %q", body)
 }
}
```

We have a few new concepts here.

1. We are leveraging more new features related to testing by using the `httptest` package. This package provides us the capability to create a new request, record that request and then check the output of that request to ensure it is what we expect.
2. Ideally our tests are light weight and we do not introduce a ton of their own dependencies such as calling other functions from our code base.

Let's add the few last couple of tests

```go
func TestPostHandler_OK(t *testing.T) {
 postTmpl := template.Must(template.New("base").Parse(`{{define "base"}}<h1>{{.Title}}</h1>{{.Content}}{{end}}`))
 app := application{
  templateCache: map[string]*template.Template{"posts": postTmpl},
  markdownCache: map[string][]byte{"hello-world": []byte("# title\n\ncontent")},
 }

 req := httptest.NewRequest(http.MethodGet, "/posts/hello-world", nil)
 req.SetPathValue("slug", "hello-world")
 rr := httptest.NewRecorder()
 app.postHandler(rr, req)

 if rr.Code != http.StatusOK {
  t.Fatalf("status = %d, want %d", rr.Code, http.StatusOK)
 }
 if ct := rr.Header().Get("Content-Type"); ct != "text/html" {
  t.Fatalf("Content-Type = %q, want text/html", ct)
 }
 if !strings.Contains(rr.Body.String(), "<h1>Hello World</h1>") {
  t.Fatalf("rendered body unexpected: %q", rr.Body.String())
 }
}
```

and lastly for not found posts.

```go
func TestPostHandler_NotFound(t *testing.T) {
 app := application{templateCache: map[string]*template.Template{"posts": template.Must(template.New("base").Parse(`{{define "base"}}ok{{end}}`))}}

 req := httptest.NewRequest(http.MethodGet, "/posts/missing", nil)
 req.SetPathValue("slug", "missing")
 rr := httptest.NewRecorder()
 app.postHandler(rr, req)

 if rr.Code != http.StatusNotFound {
  t.Fatalf("status = %d, want %d", rr.Code, http.StatusNotFound)
 }
}
```

Run these tests and ensure they pass.

```bash
go test -v
```

### Wrapping up

In this extra credit we actually did quite a bit, we refactored the application to be a bit more testable and we built out some tests to ensure any changes in the future get caught. Hopefully this gives you a good base to build on in the future. I hope you enjoyed and learned something!
