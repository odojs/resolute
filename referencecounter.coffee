module.exports = ->
  refs = {}
  ref: (key, cb) ->
    if !refs[key]?
      refs[key] = 1
      return cb()
    refs[key]++
  unref: (key, cb) ->
    if !refs[key]?
      return console.error "#{key} unref'd too much"
    refs[key]--
    if refs[key] is 0
      delete refs[key]
      cb()