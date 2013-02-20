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

api_request = (_, blog, verb, params) ->
  console.log "API " + blog + " " + verb + " " + active_requests
  setTimeout(_, 10) while active_requests >= 4

  active_requests += 1
  try
    if  use_disk_cache
      fn = ([k, v].join("=") for k,v of params).join('_')
      cache = "cache/" + verb + "_" + blog + "_" + fn + ".json"
      return JSON.parse(fs.readFileSync cache) if fs.existsSync cache

    params.api_key = key
    query = ([k, v].join("=") for k,v of params).join('&')


    response = request {uri: "http://api.tumblr.com/v2/blog/" + blog + ".tumblr.com/" + verb + "?" + query}, _
    fs.writeFile cache, response.body, _ if use_disk_cache
    return JSON.parse(response.body)
  finally
    active_requests -= 1

module.exports =

  fetch_likes: (_, blog, callback)->
    offset = 0
    liked = 1
    found = `undefined`
    while offset < liked and (found is `undefined` or found > 0)
      feed = api_request _, blog, "likes", {limit: 20, offset: offset}

      liked = feed.response.liked_count
      liked_posts = feed.response.liked_posts
      if liked_posts and liked_posts.length > 0
        offset += liked_posts.length
      else
        offset += 10

      found = 0
      for liked_post in liked_posts
        found++ if callback(_, liked_post.blog_name, liked_post.id)

  posts: (blog, post_id, _) ->
    feed = api_request _, blog, "posts", {notes_info: true, reblog_info: true, id: post_id}
    return undefined if !feed.response.posts || feed.response.posts.length == 0
    feed.response.posts[0]

