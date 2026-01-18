---
title: "Building a blog in Go Part 2"
date: 2025-11-16
summary: "This part continues building a simple blog in Go, covering template rendering, dynamic routing, markdown parsing, and development workflow improvements."
draft: false
tags:
  - "#Go"
  - "#Development"
---

Welcome back!

In part 1 we built a skeleton of a blog. We have a web server and we can read a markdown file from our content directory. We obviously need a bit more to make something usable.

1. Create a new file `index.tmpl` and add the following content

   ```html
   <!DOCTYPE html>
   <html lang="en">
   <head>
     <meta charset="UTF-8">
     <meta name="viewport" content="width=device-width, initial-scale=1.0">
     <title>My Blog</title>
   </head>
   <body>
     <h1>Hi</h1>
   </body>
   </html>
   ```

2. Now we need to read that index file. Let's get rid of this code `fmt.Println("cache", cache)` and replace it with this.

```go
var tmplFile = "index.tmpl" // create a variable that stores the name of the file
tmpl, err := template.New(tmplFile).ParseFiles(tmplFile) // use template.New() to create a new 'template set' with the filename
if err != nil { 
  log.Fatalf("error parsing template: %v", err) // check for errors, if we hit one its fatal..exit
}
```

Let's examine this code and what it does. We are creating a variable that stores the filename. We then use `template.New().ParseFiles()` to parse that `index.tmpl` file. This function will create a `*template.Template` and an `error`, you can choose to ignore this error if you want. The next couple of lines will simply check if there was an error and exit if there was one.

1. Now we have our tmpl file parsed, we need to render / execute it. Let's open that handler and add the following code.

```go
 // register a handle function for the route default "/" and write the string "hi" in a byte slice
 http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
  err := tmpl.Execute(w, nil)
  if err != nil {
   http.Error(w, err.Error(), http.StatusInternalServerError)
  }
 })
```

This code will use `template.Execute()` which will render a template to a `io.writer`. In this case our output to our http server. Let's go ahead and run the server and open the browser. We want to make sure we see the html content we put in `index.tmpl`

An easy way to check this is to open the terminal and run

```bash
curl http://localhost:5040
```

You should see some of the html output that we wrote.

```bash
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>My Blog</title>
</head>
<body>
  <h1>Hi</h1>
</body>
</html>%  
```

## Rendering our markdown files

We have our markdown posts stored in a map as a `[]byte`. We need to render these out to the main page as a link. Part of the reason we removed the `.md` in this line of code

```go
// remove the .md filename and add the data to the map
cache[strings.TrimSuffix(f, ".md")] = data
```

Is that we will use it as a 'slug' in our router to route requests to various posts.

We need to store all of our post links and render them on our page. Go ahead and create the following struct to hold our page data.

```go
type HomePageData struct {
 Urls []string
}
```

In our main function, we need to read the slugs from our cache and store them in our homePageData structure. Add the following lines to `main.go` right under the creation of our cache.

```go
 // create our homePageDate struct
 homePageData := HomePageData{
  Title: "Home",
 }

 // loop through our cache and add each url to the homePageData struct
 for k := range markdownCache {
  homePageData.Urls = append(homePageData.Urls, k)
 }
```

We now have our `homePageData.Urls` loaded with slugs that we want to render. Let's get this to render. Update our `/` handler.

```go
http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
  err := tmpl.Execute(w, homePageData)
  if err != nil {
   http.Error(w, err.Error(), http.StatusInternalServerError)
  }
 })
```

We need to update our `home.tmpl` template to render this data as well. Open it and make the following modifications.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>My Blog</title>
</head>
<body>
  <h1>Hi</h1>
  {{ range .Urls }}
    <a href="/posts/{{.}}">{{.}}</a>
  {{ end }}
</body>
</html>
```

The code in the template will iterate through our the slice in our data structure that we passed in the handler. It will then render the actual content in the href tag.

Let's go ahead and create two more markdown files to ensure everything is working correctly. Add the following files to the `content` folder, run the following in terminal or create them manually.

```bash
touch content/secondpost.md      
echo "# Second Post \n This is the second post" > content/secondpost.md 
touch content/thirdpost.md                                             
echo "# Third Post\n \n This is the third post" > content/thirdpost.md 
```

Make sure to stop and start the server and run curl again or pull the browser

```bash
curl http://localhost:5040
```

You should see all 3 posts now on the main page.

## Adding routing for each post

Let's work on the routing and make sure these links each route to an actual post. The behavior we want here is for someone to click the link and it route to `/posts/slug` with slug being the name of the file (without .md). I realize at this point you might think these are terrible names of blog posts, and I would agree with you. We have some options to fix that in Part 3.

Let's create a new handler that will handle routes going to `/posts/{id}` with id being your slug.

```go
http.HandleFunc("/posts/{slug}", func(w http.ResponseWriter, r *http.Request) {
  slug := r.PathValue("slug")
  if slug == "" {
   http.Error(w, "Post Not Found", http.StatusNotFound)
   return
  }

  w.Write([]byte(slug))
 })
```

In this function we are catching any requests going to `/posts/id` with id just being an identifier we can use in the handler. We could rename `{slug}` with anything if we wanted to. We are then going to fetch what was passed in by using the requests `r.PathValue("slug")` function. We check if we found anything and if so we just write out value of `slug`.

> Note that `r.PathValue()` was added in Go 1.22, just ensure you are using the latest version.

Run your server and click one of the links, it should route you to a page that shows the slug value that was passed through.

Now all we really need to do is get that markdown rending as HTML. Before we do that though let's do a couple of quick quality of life things squared away.

### Installing Air

If it is not super obvious yet, stopping and starting your server is a total pain in the ass and slows down development for quick changes. Let's remedy this by installing a package called `Air`. This will monitor for file system changes and automatically restart the server. In your command line run the following command

```bash
go install github.com/air-verse/air@latest
```

Now in the project itself run the following command

```bash
air init
```

This will create a `.air.toml` file you can pretty much just leave alone for now. Assuming your server is stopped, go ahead and run `air` in the console. If everything worked correctly you should see the Air logo and text about running and building. No more starting and stopping our server, going forward you can change your files and save and the server will automatically restart. If you restart the project make sure to start `air` again. It will not start automatically.

### GoldMark Markdown to HTML

Writing your own code to convert Markdown to HTML would be a fun project but not something I want to waste time doing. There are literally a hundreds of projects that do that already. Let's go ahead and grab one and get it setup.

In the terminal go ahead and run the following command

```bash
go get github.com/yuin/goldmark 
```

This will install the Goldmark markdown parser. There are quite a few parsers out there, this one has some of the easiest instructions to follow and has nice features if you want to get fancy and extend it.

Let's go back to that handler we had that was looking for a slug and make the following changes. We will walk through each change.

```go
http.HandleFunc("/posts/{slug}", func(w http.ResponseWriter, r *http.Request) {
  // fetch the slug from the path
  post := r.PathValue("slug")
  if post == "" {
   http.Error(w, "Post Not Found", http.StatusNotFound)
   return
  }

  // find our post in the cache
  data, found := cache[post]
  if !found {
   http.Error(w, "Post Not Found", http.StatusNotFound)
   return
  }

  // create a buffer for our post and convert the markdown to html, writing the output to
  // the buffer
  var buf bytes.Buffer
  if err := goldmark.Convert(data, &buf); err != nil {
    http.Error(w, "Post Not Found", http.StatusNotFound)
   return
  }

  // use io.copy to copy the buffer to the http.responsewriter
  io.Copy(w, &buf)
 })
```

This looks like alot but it is actually pretty straightforward. You already know what we are doing in the top part regarding fetching the post from the cache. The next part has us create a `bytes.Buffer`, a bytes buffer is a writable data structure that allows you to fill it with bytes. We then use goldmark to covert the bytes that we stored in cache earlier and convert them to html. Lastly we use `io.Copy(w,&buf)` to copy the buffer to the `http.responsewriter`.

Save your changes, head to your browser. When you click on one of the posts you should see it now rendering out the post content in html. Note that while it renders as HTML, we should be setting the `Content-Type` header to `text/html` using this line.

```go
  w.Header().Set("Content-Type", "text/html")
```

This is not pretty, actually the code is pretty sloppy at this point, but who cares. This is not being used to guide missles or land stuff on the moon. We have a working blog where we can add posts in markdown format and render them in HTML. Why limit yourself to a blog even? You can render content to HTML by simply adding new markdown files and restarting the server. This is ultimately a static site generator and you could use as a blog.

In Part 3 we will focus on making this look a little bit better and tidying things up a bit more.

One last thing, go ahead and create a `.gitignore` file so we can add our `.air.toml` file. Run the following command

```bash
echo ".air.toml" > .gitignore  
```

This will ensure that our toml file is not saved into our repo. Go ahead and commit this code and we will clean things up in part 3.
