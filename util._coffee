"use strict"

neo4j = require("neo4j")
Node = require("neo4j/lib/Node")
db = new neo4j.GraphDatabase(process.env.NEO4J_URL or "http://localhost:7474")

console.log "using neo4j-server: " + db.url

tumblr = require("./tumblr._coffee")
pool = require("./pool._coffee")

my_id = 0

make_id = ->
  new Date().getTime() + "_" + (my_id++)

getOrCreateNode = (index, key, data, _) ->
  node = JSON.stringify key: key, value: data[key], properties: data
  response = db._request.post uri: db.url + "/db/data/index/node/#{index}?unique", body: node, _
  db.getNode response.body.self, _
#  result = db.query "START n=node:node_auto_index(#{key}={id}) WITH count(*) as c " +
#                    "FOREACH(x in FILTER(v in [c] : c = 0) : CREATE n={data}) WITH c " +
#                    "START n=node:node_auto_index(#{key}={id}) RETURN n",
#                    id: data[key], data: data, _
#  result[0].n




getOrCreateBlog = (blog_name, _)->
  getOrCreateNode "blog", "name", name: blog_name, _type: "blog",_

getOrCreatePost = (post, _)->
  blog_node = getOrCreateBlog post.blog_name, _
  post_node = getOrCreateNode "post", "id", _type: "post", id: post.id, type: post.type, timestamp: post.timestamp,_
  db.query "START blog=node({blog}), post=node({post}) CREATE UNIQUE blog-[:POST]->post",
           blog: blog_node.id, post: post_node.id, _
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
  query = db.query "START a=node({a}),b=node({b}) MATCH p=a-[?:#{type }]->b " +
                   "CREATE UNIQUE a-[:#{type}]->b RETURN p=null as created",
                   a: a.id, b: b.id, _
  query[0].created

add_media = (post_node, data, _)->
  db.query "START post=node({post}) CREATE UNIQUE post-[:PHOTO]->({data})",
           post: post_node.id, data: data, _

fetch_post = (blog_name, post_id, logger, _) ->
  try
    result = db.query("START post=node:post(id={id}) RETURN post", id: post_id, _)[0]
    post_node = result.post if result
  catch ignored
  #  return [post_node, 0]  if post_node and new Date().getTime() - post_node.data.last_checked < 12 * 3600000

  post = tumblr.posts blog_name, post_id, _
  return [undefined, 0] unless post

  unless post_node?
    post_node = getOrCreatePost(post, _)
    try
      if post.type == 'video'
        add_media(post_node, {url: post.thumbnail_url, width: post.thumbnail_width, height: post.thumbnail_height}, _)

      if post.photos
        for photo in post.photos
          add_media(post_node, photo.original_size, _)

      for tag in post.tags
        tag_node = getOrCreateNode "tag", "tag", tag: tag,_
        unique_rel post_node, tag_node, "TAG", _

    catch error
      console.log error.stack
      console.log post

      throw error
  count = 0

  for note in post.notes
    blog_node = getOrCreateBlog(note.blog_name, _)
    count++ if (note.type in ["like", "reblog"]) && unique_rel(blog_node, post_node, note.type.toUpperCase(), _)

  post_node.data.last_checked = +new Date()
  post_node.save(_)

  if post.reblogged_from_id and post.reblogged_from_name
    try
      [post_reblog_node, count_reblog] = fetch_post(post.reblogged_from_name, post.reblogged_from_id, logger, _)
      if post_reblog_node
        console.log "#{post_node}-[:IS_REBLOG]->#{post_reblog_node}"
        unique_rel post_node, post_reblog_node, "IS_REBLOG", _
        count += count_reblog
    catch ignored
      console.log ignored.stack

  [post_node, count]

module.exports =
  query: (cypher, params, _)->
    console.log cypher
    console.log params
    start = +new Date()
    try
      db.query cypher, params, _
#    for r in res
#      console.log JSON.stringify(r)
    finally
      end = +new Date()
      console.log end - start

  fetch_post: fetch_post

  add_likes: (blog, logger, _) ->
    blog_node = getOrCreateBlog(blog, _)
    log_id = make_id()
    logger "likes " + blog, log_id, true

    found = tumblr.fetch_likes _, blog, (_, post) ->
      logger "likes #{blog} fetching #{post.blog_name}/#{post.id}", log_id, true

      [post_node, found] = fetch_post post.blog_name, post.id, logger, _
      found++ if post_node && unique_rel blog_node, post_node, "LIKE", _
      found

    blog_node.data.last_checked = +new Date()
    blog_node.save _

    logger "likes #{blog} #{found}", log_id, false

