references = require './referencecounter'

module.exports = (bus, bindings) ->
  bindings ?= {}
  subscriptions = {}
  refs = references()
  subscribe: (key, cb) ->
    refs.ref key, ->
      subscriptions[key] = yes
      return if !bindings[key]?
      for address, _ of bindings[key]
        bus.subscribe address, key
  unsubscribe: (key, cb) ->
    refs.unref key, ->
      delete subscriptions[key]
      return if !bindings[key]?
      for address, _ of bindings[key]
        bus.unsubscribe address, key
  bind: (key, addresses) ->
    addresses = [addresses] unless addresses instanceof Array
    bindings[key] = {} if !bindings[key]?
    for address in addresses
      if !bindings[key][address]? and subscriptions[key]
        bus.subscribe address, key
      bindings[key][address] = yes
  unbind: (key, addresses) ->
    addresses = [addresses] unless addresses instanceof Array
    return if !bindings[key]?
    for address in addresses
      if bindings[key][address] and subscriptions[key]
        bus.unsubscribe address, key
      delete bindings[key][address]
