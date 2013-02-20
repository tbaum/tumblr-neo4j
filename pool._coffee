"use strict"
flows = require "streamline/lib/util/flows"

module.exports = (_, results, size, callback) ->
  active = 0

  wrap = (_, result, index) ->
    setTimeout(_, 10) while active > 5
    # flows.nextTick _  while active > size
    active++
    try
      callback _, result, index
    finally
      active--

  size = 1  unless size > 0
  pool = ( wrap null, result for result in results )

  future _ for future in pool
