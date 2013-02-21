"use strict"

neo4j = require("neo4j")
db = new neo4j.GraphDatabase(process.env.NEO4J_URL or "http://localhost:7474")

console.log "using neo4j-server: " + db.url

tumblr = require("./tumblr._coffee")
pool = require("./pool._coffee")

my_id = 0

make_id = ->
  my_id++
  new Date().getTime() + "_" + my_id

getNode = (type, id, _) ->
  try
    return db.getIndexedNode(type, type, id, _)
  catch error
    return null  if error.message.exception is "NotFoundException"
    throw error

getOrCreateNode = (type, id, data, _) ->
  node = getNode(type, id, _)
  return node if node?

  node = db.createNode(data).save(_)
  try
    node.index type + "?unique", type, id, _
    return node
  catch error
    node.del _
    return db.getNode(error.message.indexed, _)


getOrCreateBlog = (blog_name, _)->
  getOrCreateNode("blog", blog_name, {_type: "blog", name: blog_name}, _)

getOrCreatePost = (post, _)->
  post_node = getOrCreateNode "post", post.id, {id: post.id, type: post.type, timestamp: post.timestamp, _type: "post"}, _
  blog_node =  getOrCreateBlog(post.blog_name, _)
  unique_rel blog_node, post_node, "post", _
  post_node


# retry = 0
#retry = (count, _function) ->
#  args = Array::slice.call(arguments_, 2)
#  retry = 0
#  while retry++ < count
#    try
#      return _function.apply(this, args)
#  _function.apply this, args


unique_rel = (a, b, type, _) ->
  query = db.query("START a=node({a}),b=node({b}) MATCH p=a-[?:" + type + "]->b " +
                   "CREATE UNIQUE a-[:" + type + "]->b " +
                   "RETURN not(p <> null) as created",
                   {a: a.id, b: b.id}, _)
  query[0].created


fetch_post = (_, blog_name, post_id, logger) ->
  post_node = getNode("post", post_id, _)
  #  return [post_node, 0]  if post_node and new Date().getTime() - post_node.data.last_checked < 12 * 3600000

  post = tumblr.posts(blog_name, post_id, _)
  return [undefined, 0] unless post

  unless post_node?
    post_node = getOrCreatePost(post, _)
    try
      if post.type == 'video'
        video_node = db.createNode({url: post.thumbnail_url, width: post.thumbnail_width, height: post.thumbnail_height}).save(_)
        unique_rel(post_node, video_node, "photo")

      if post.photos
        for photo in post.photos
          photo_node = db.createNode(photo.original_size).save(_)
          unique_rel(post_node, photo_node, "photo")

      #    if post.tags
      for tag in post.tags
        tag_node = getOrCreateNode("tag", tag, {_type: "tag", tag: tag}, _)
        unique_rel(tag_node, post_node, "tag", _)
    catch error
      console.log error.stack
      console.log post

      throw error
  #  add_notes = (post_node, notes, _) ->
  count = 0

  for note in post.notes
    blog_node = getOrCreateBlog(note.blog_name, _)
    count++ if (note.type in ["like", "reblog"]) && unique_rel(blog_node, post_node, note.type, _)
  #  added

  #  count = add_notes post_node, post.notes, _
  post_node.data.last_checked = new Date().getTime()
  post_node.save(_)

  if post.reblogged_from_id and post.reblogged_from_name
    try
      [post_reblog_node, count_reblog] = fetch_post(_, post.reblogged_from_name, post.reblogged_from_id, logger)
      if post_reblog_node
        unique_rel post_node, post_reblog_node, "is_reblog", _
        count += count_reblog
    catch ignored

  [post_node, count]

module.exports =
  query: (cypher, params, _)->
    console.log cypher
    console.log params
    db.query cypher, params, _

  fetch_post: fetch_post

  add_likes: (_, blog, logger) ->
    blog_node = getOrCreateBlog(blog, _)
    log_id = make_id()
    logger "likes " + blog, log_id, true

    tumblr.fetch_likes _, blog, (_, liked_blog_name, liked_post_id)->
      logger "likes " + blog + " fetching " + liked_blog_name + "/" + liked_post_id, log_id, true

      [post_node, found] = fetch_post(_, liked_blog_name, liked_post_id, logger)
      found++ if post_node && unique_rel(blog_node, post_node, "like", _)
      found

    blog_node.data.last_checked = new Date().getTime()
    blog_node.save(_)

    results = blog_node.outgoing(["like", "post", "reblog"], _)
    logger "likes " + blog + " " + (results && results.length), log_id, false

