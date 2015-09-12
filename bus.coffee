cuid = require 'cuid'
async = require 'odo-async'
Publish = require './publish'
Receive = require './receive'
Shulz = require 'shulz'
Hub = require 'odo-hub'

module.exports = (publicaddress, addresses) ->
  bindaddresses = [publicaddress]
  if addresses?
    bindaddresses = bindaddresses.concat addresses

  # internal state, eventually shulz
  subscriptions = {}
  _subscribe = (key, address) ->
    subscriptions[key] = {} if !subscriptions[key]?
    subscriptions[key][address] = yes
    publisher.register address, address
  _unsubscribe = (key, address) ->
    return if !subscriptions[key]?
    delete subscriptions[key][address]

  hub = Hub.create()
  hub.every '_subscribe', (m, cb) ->
    for key in m.keys
      _subscribe key, m.address
    cb()
  hub.every '_unsubscribe', (m, cb) ->
    for key in m.keys
      _unsubscribe key, m.address
    cb()

  publisher = Publish()
  receiver = Receive bindaddresses, (envelope, done) ->
    envelope = JSON.parse envelope.toString()
    tasks = []
    for key in envelope.keys
      do (key) ->
        tasks.push (cb) ->
          hub.emit key, envelope.data, cb
    async.parallel tasks, done

  register: (name, addresses) ->
    publisher.register name, addresses

  publish: (keys, data, cb) ->
    keys = [keys] unless keys instanceof Array
    addresses = {}
    for key in keys
      continue if !subscriptions[key]?
      for address, _ of subscriptions[key]
        addresses[address] = yes
    addresses = Object.keys addresses
    msgid = cuid()
    if addresses.length is 0
      async.delay cb if cb?
      return msgid
    envelope =
      id: msgid
      keys: keys
      sent: new Date()
      data: data
    message = JSON.stringify envelope
    publisher.publish msgid, message, addresses, ->
      async.delay cb if cb?
    msgid

  subscribe: (address, keys, cb) ->
    keys = [keys] unless keys instanceof Array
    tasks = []
    subscribemsgids = []
    publisher.register address, address
    for key in keys
      do (key) ->
        msgid = cuid()
        subscribemsgids.push msgid
        envelope =
          id: msgid
          keys: ['_subscribe']
          sent: new Date()
          data:
            keys: keys
            address: publicaddress
        message = JSON.stringify envelope
        tasks.push (cb) ->
          publisher.publish msgid, message, address, cb
    async.parallel tasks, ->
      async.delay cb if cb?
    subscribemsgids

  unsubscribe: (address, keys, cb) ->
    keys = [keys] unless keys instanceof Array
    tasks = []
    unsubscribemsgids = []
    publisher.register address, address
    for key in keys
      do (key) ->
        msgid = cuid()
        unsubscribemsgids.push msgid
        envelope =
          id: msgid
          keys: ['_unsubscribe']
          sent: new Date()
          data:
            keys: keys
            address: publicaddress
        message = JSON.stringify envelope
        tasks.push (cb) ->
          publisher.publish msgid, message, address, cb
    async.parallel tasks, ->
      async.delay cb if cb?
    unsubscribemsgids

  hub: hub

  close: ->
    publisher.close()
    receiver.close()