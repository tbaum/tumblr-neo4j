"use strict"

express = require("express")
neo4j = require("neo4j")

util = require("./util._coffee")
pool = require("./pool._coffee")

app = express()
app.configure ->
  express.static.mime.define 'application/x-javascript': ['coffee']
  app.use express.static __dirname + "/public"

server = require("http").createServer(app)

io = require("socket.io").listen(server)
io.set "log level", 1

server.listen parseInt(process.env.PORT or 3000)

logger = (msg, id, active) ->
  io.sockets.emit "log", if id then {message: msg, id: id, active: active } else { message: msg }

io.sockets.on "connection", (socket, _) ->
  # TODO
  #socket.on "stop", (data, _) ->
  #  stop_it = true
  socket.on "add-likes", (data, _) ->
    try
      util.add_likes data.blog, logger, _

      results = util.query("START blog=node:blog(name={blog}) " +
                           "MATCH blog-[:REBLOG|LIKE|POST]->post<-[:REBLOG|LIKE|POST]-other_blog " +
                           "WHERE other_blog.last_checked? < { checked } " +
                           "RETURN other_blog.name as blog_name ",
                           blog: data.blog, checked: +new Date() - 864000000, _)

      pool _, results, 2, (_, r)->
        util.add_likes r.blog_name, logger, _

    catch e
      console.log e.stack
      socket.emit "error", e.stack

  socket.on "show-blog", (data, _) ->
    try
      socket.emit "show",
                  recommend: util.query("START my_blog=node:blog(name={blog}) " +
                                        "MATCH my_blog-[:REBLOG|LIKE|POST]->my_post<-[:REBLOG|LIKE|POST]-other_blog, " +
                                        " other_blog-[:REBLOG|LIKE|POST]->post " +
                                        " ,known_post=(my_blog)-[?:REBLOG|LIKE|POST]->post, pn=(post)-[?:IS_REBLOG]->() WHERE length(pn) <> 1 AND length(known_post) <> 1 " +
#                                        " WHERE NOT((post)-[:IS_REBLOG]->()) AND NOT( (my_blog)-[:REBLOG|LIKE|POST]->(post) ) " +
                                        "WITH  post,count(*) as c " +
                                        "MATCH blog-[:POST]->post-[:PHOTO]->p " +
                                        "WHERE has(p.url) " +
                                        "RETURN blog.name as blog_name, post.id as post_id, p.url as url, c ORDER BY c desc limit 20",
#                                        "RETURN collect(blog.blog_name) as blog_name, collect(post.post_id) as post_id, p.url as url, c,   id(post) ORDER BY c desc limit 20",
                                        blog: data.blog, _)

                  posts: util.query("START my_blog=node:blog(name={blog}) " +
                                    "MATCH my_blog-[:REBLOG|LIKE|POST]->(post) " +
                                    ", pn=(post)-[?:IS_REBLOG]->() WHERE length(pn) <> 1 " +
#                                    " WHERE NOT((post)-[:IS_REBLOG]->()) " +
                                    "WITH post,count(*) as c " +
                                    "MATCH blog-[:POST]->post-[:PHOTO]->p " +
                                    "WHERE has(p.url) " +
                                    "RETURN blog.name as blog_name, post.id as post_id, p.url as url, c ORDER BY c desc limit 20",
                                    blog: data.blog, _)
    catch e
      console.log e.stack
      socket.emit "error", e.stack

  socket.on "show-post", (data, _) ->
    try
      socket.emit "show",
                  post: util.query("START my_post=node:post(id={post}) " +
                                   "MATCH my_post<-[:REBLOG|LIKE|POST]-other_blog-[:REBLOG|LIKE|POST]->post" +
                                   ", pn=(post)-[?:IS_REBLOG]->() WHERE length(pn) <> 1 " +
#                                   " WHERE NOT((post)-[:IS_REBLOG]->()) " +
                                   "WITH post,count(*) as c " +
                                   "MATCH blog-[:POST]->post-[:PHOTO]->p " +
                                   "WHERE has(p.url) " +
                                   "RETURN blog.name as blog_name, post.id as post_id, p.url as url, c ORDER BY c desc limit 50",
                                   post: data.post, _)
    catch e
      console.log e.stack
      socket.emit "error", e.stack
