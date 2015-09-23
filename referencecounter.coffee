module.exports = ->
  refs = {}
  ref: (key, cb) ->
    if !refs[key]?
      refs[key] = 1
      cb()
      return yes
    refs[key]++
    no
  unref: (key, cb) ->
    if !refs[key]?
      console.error "#{key} unref'd too much"
      return null
    refs[key]--
    if refs[key] = 0
      delete refs[key]
      cb()
      return yes
    return no