"use strict";

use_disk_cache = process.env.USE_CACHE

flows = require "streamline/lib/util/flows"

fs = require("fs")
key = process.env.TUMBLR_API_KEY || String(fs.readFileSync(".tumblr_api_key")).split("\n")[0] || fail "missing env.TUMBLR_API_KEY"

console.log "using tumblr_api_key: " + key

request = require("request")

if use_disk_cache
  fs.mkdirSync "cache" unless fs.existsSync "cache"

active_requests = 0

api_request = (blog, verb, params, _) ->
  setTimeout(_, 10) while active_requests >= 4

  active_requests += 1
  try
    if use_disk_cache
      cacheFile = "cache/#{verb}_#{blog}_#{ ([k, v].join("=") for k,v of params).join('_') }.json"
      return JSON.parse(fs.readFileSync(cacheFile)) if fs.existsSync cacheFile

    params.api_key = key
    query = ([k, v].join("=") for k,v of params).join('&')

    response = request uri: "http://api.tumblr.com/v2/blog/#{blog}.tumblr.com/#{verb}?#{query}", _
    fs.writeFile(cacheFile, response.body, _) if use_disk_cache

    return JSON.parse(response.body)
  finally
    active_requests -= 1

module.exports =

  fetch_likes: (_, blog, callback)->
    offset = 0
    liked = 1
    while offset < liked and (!found? or found > 0)
      feed = api_request blog, "likes", limit: 20, offset: offset,_
      return 0 unless feed.response.liked_posts

      liked = feed.response.liked_count
      liked_posts = feed.response.liked_posts

      offset += if liked_posts and liked_posts.length > 0 then liked_posts.length else 10

      found = 0
      for liked_post in liked_posts
        found++ if callback _, liked_post
    found

  posts: (blog, post_id, _) ->
    feed = api_request blog, "posts", notes_info: true, reblog_info: true, id: post_id, _
    return undefined if !feed.response.posts || feed.response.posts.length == 0
    feed.response.posts[0]

