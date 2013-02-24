$(document).ready ->
  socket = io.connect location.protocol + "//" + location.hostname

  $("#loader").hide()

  $(window).hashchange ->
    if location.hash
      loc = location.hash.substr(1).split(":")
      $("#loader").show()
      socket.emit loc[0], {blog: loc[1], post: loc[2]}

  $(window).hashchange()

  goTo = (hash)->
    location.hash = hash.join ':'
    $(window).hashchange()
    false

  $.fn.show_post = (blog, post_id)->
    @click ->
      goTo ["show-post", blog, post_id]

  $("#add-likes").click ->
    goTo ["add-likes", $("#blog").val()]

  $("#show").click ->
    goTo ["show-blog", $("#blog").val()]

  $("#stop").click ->
    goTo ["stop"]

  socket.on "error", (data) ->
    console.log(data)

  socket.on "log", (data) ->
    unless data.id and (pre = $("#pre" + data.id)) and pre.length > 0
      pre = $("<pre/>").attr("id", "pre" + data.id).prependTo($("#log"))

    if data.active then  pre.addClass "active" else pre.removeClass "active"
    if data.message then pre.text data.message else pre.remove()

  socket.on "show", (data) ->
    console.log data
    display = $("#image-display")
    display.html ""
    for key,elements of data
      display.append $("<h4/>").text(key)
      $(elements).each ->
        display.append $("<a target='_blank'/>").attr("href", "http://" + @blog_name + ".tumblr.com/post/" + @post_id)
                         .append($("<div/>").addClass("references").text(@c).show_post(@blog_name, @post_id))
                         .append($("<img/>").attr("height", 140).attr("src", @url))

    $("#loader").hide()

