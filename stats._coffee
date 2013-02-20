"use strict"

posts = 0

module.exports =
  current_post: ->
    posts

  add_post: ->
    posts += 1

  rm_post: ->
    posts += 1
