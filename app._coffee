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
      util.add_likes _, data.blog, logger
      #    results = db.query("START blog=node:blog(blog={blog}) " +
      #                       "MATCH blog-[:like|reblog|post]->post " +
      #                       "WHERE post.last_checked? < { checked } " +
      #                       "RETURN post.blog_name as blog_name,post.id as id",
      #                       { blog: data.blog, checked: new Date().getTime() - 18000000}, _)
      #    pool _, results, 2, (_, result)->
      #      util.fetch_post(_, result.blog_name, result.id, logger)

      results = util.query("START blog=node:blog(blog={blog}) " +
                           "MATCH blog-[:like|reblog|post]->post<-[:like|reblog|post]-other_blog " +
                           "WHERE other_blog.last_checked? < { checked } " +
                           "RETURN other_blog.name as name ",
                           { blog: data.blog, checked: new Date().getTime() - 864000000 }, _)

      pool _, results, 2, (_, r)->
        util.add_likes(_, r.name, logger)
    catch e
      console.log e.stack
      socket.emit "error", e.stack

  socket.on "show-blog", (data, _) ->
    try
      socket.emit "show",
                  recommend: util.query("START my_blog=node:blog(blog={blog}) " +
                                        "MATCH my_blog-[:reblog|like|post]->my_post<-[:blog|like|reblog]-other_blog, " +
                                        " other_blog-[:blog|like|reblog]->post " +
#                                        " ,known_post=(my_blog)-[?:reblog|like|post]->post, pn=(post)-[?:is_reblog]->() WHERE length(pn) <> 1 AND length(known_post) <> 1 " +
                                        " WHERE NOT((post)-[:is_reblog]->()) AND NOT( (my_blog)-[:reblog|like|post]->(post) ) " +
                                        "WITH post,count(*) as c " +
                                        "MATCH blog-[:post]->post-[:photo]->p " +
                                        "WHERE has(p.url) " +
                                        "RETURN blog.name as blog_name, post.id as post_id, p.url as url, c ORDER BY c desc limit 20",
                                        { blog: data.blog }, _)

                  posts: util.query("START my_blog=node:blog(blog={blog}) " +
                                    "MATCH my_blog-[:reblog|like|post]->(post) " +
#                                    ", pn=(post)-[?:is_reblog]->() WHERE length(pn) <> 1 " +
                                    " WHERE NOT((post)-[:is_reblog]->()) " +
                                    "WITH post,count(*) as c " +
                                    "MATCH blog-[:post]->post-[:photo]->p " +
                                    "WHERE has(p.url) " +
                                    "RETURN blog.name as blog_name, post.id as post_id, p.url as url, c ORDER BY c desc limit 20",
                                    { blog: data.blog }, _)
    catch e
      console.log e.stack
      socket.emit "error", e.stack

  socket.on "show-post", (data, _) ->
    try
      socket.emit "show",
                  post: util.query("START my_post=node:post(post={post}) " +
                                   "MATCH my_post<-[:blog|like|reblog]-other_blog-[:blog|like|reblog]->post" +
#                                   ", pn=(post)-[?:is_reblog]->() WHERE length(pn) <> 1 " +
                                   " WHERE NOT((post)-[:is_reblog]->()) " +
                                   "WITH post,count(*) as c " +
                                   "MATCH blog-[:post]->post-[:photo]->p " +
                                   "WHERE has(p.url) " +
                                   "RETURN blog.name as blog_name, post.id as post_id, p.url as url, c ORDER BY c desc limit 50",
                                   { post: data.post }, _)
    catch e
      console.log e.stack
      socket.emit "error", e.stack
