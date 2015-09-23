cuid = require 'cuid'
async = require 'odo-async'
Publish = require './publish'
Receive = require './receive'
shulz = require 'shulz'
resolve = require('path').resolve
mkdirp = require 'mkdirp'

module.exports = (options) ->
  _fin = no
  advertise = options.advertise
  advertise ?= options.bind
  bind = options.bind

  datadir = resolve process.cwd(), options.datadir
  mkdirp.sync datadir

  incoming = options.incoming
  incoming ?= shulz.open resolve datadir, './incoming.shulz'
  outgoing = options.outgoing
  outgoing ?= shulz.open resolve datadir, './outgoing.shulz'
  subscriptions = options.subscriptions
  subscriptions ?= shulz.open resolve datadir, './subscriptions.shulz'
  hub = options.hub
  hub ?= require 'odo-hub/parallel'

  _ondrained = []
  _onoutgoingempty = ->
    return if incoming.length() isnt 0
    cb() for cb in _ondrained
    _ondrained = []
  _onincomingempty = ->
    return if outgoing.length() isnt 0
    cb() for cb in _ondrained
    _ondrained = []

  publisher = Publish()
  exec = (envelope, cb) ->
    tasks = []
    for key in envelope.keys
      do (key) ->
        tasks.push (cb) ->
          hub.emit key, envelope.data, cb
    async.parallel tasks, cb

  # replay incoming messages
  replayincoming = []
  for _, envelope of incoming.all()
    replayincoming.push envelope
  async.delay ->
    for envelope in replayincoming
      do (envelope) ->
        exec envelope, ->
          incoming.clear envelope.id
          _onincomingempty() if incoming.length() is 0
  receiver = Receive bind, (envelope, done) ->
    envelope = JSON.parse envelope.toString()
    incoming.set envelope.id, envelope
    # TODO: make this repeatable, trottleable, parallelisable, etc.
    async.delay ->
      exec envelope, ->
        incoming.clear envelope.id
        _onincomingempty() if incoming.length() is 0
    done()

  # persistent subscriber store
  for _, addresses of subscriptions.all()
    for address, _ of addresses
      publisher.register address, address

  _subscribe = (key, address) ->
    subs = subscriptions.get key
    subs ?= {}
    subs[address] = yes
    subscriptions.set key, subs
    publisher.register address, address
  _unsubscribe = (key, address) ->
    subs = subscriptions.get key
    subs ?= {}
    delete subs[address]
    subscriptions.set key, subs
  _removedestination = (key, address) ->
    for key, subs of subscriptions.all()
      continue if !subs[address]?
      delete subs[address]
      subscriptions.set key, subs

  hub.every '_subscribe', (m, cb) ->
    for key in m.keys
      _subscribe key, m.address
    cb()
  hub.every '_unsubscribe', (m, cb) ->
    for key in m.keys
      _unsubscribe key, m.address
    cb()
  hub.every '_removedestination', (m, cb) ->
    _removedestination m.address
    cb()

  # replay outgoing messages
  replayoutgoing = []
  for _, envelope of outgoing.all()
    replayoutgoing.push envelope
    for address in envelope.addresses
      publisher.register address, address
  async.delay ->
    for envelope in replayoutgoing
      do (envelope) ->
        message = JSON.stringify envelope
        publisher.publish envelope.id, message, envelope.addresses, ->
          outgoing.clear envelope.id
          _onoutgoingempty() if outgoing.length() is 0

  send = (addresses, msgid, keys, data, cb) ->
    envelope =
      id: msgid
      keys: keys
      addresses: addresses
      sent: new Date()
      data: data
    outgoing.set msgid, envelope
    message = JSON.stringify envelope
    # TODO: make this repeatable, trottleable, parallelisable, etc.
    publisher.publish msgid, message, addresses, ->
      outgoing.clear msgid
      _onoutgoingempty() if outgoing.length() is 0
      async.delay cb if cb?

  publish: (keys, data) ->
    keys = [keys] unless keys instanceof Array
    addresses = {}
    for key in keys
      subs = subscriptions.get key
      continue if !subs?
      for address, _ of subs
        addresses[address] = yes
    addresses = Object.keys addresses
    msgid = cuid()
    return msgid if addresses.length is 0
    send addresses, msgid, keys, data
    msgid

  send: (key, data, address) ->
    publisher.register address, address
    msgid = cuid()
    send [address], msgid, [key], data
    msgid

  subscribe: (address, keys) ->
    keys = [keys] unless keys instanceof Array
    subscribemsgids = []
    publisher.register address, address
    for key in keys
      do (key) ->
        msgid = cuid()
        subscribemsgids.push msgid
        data =
          keys: keys
          address: advertise
        send address, msgid, ['_subscribe'], data
    subscribemsgids

  unsubscribe: (address, keys) ->
    keys = [keys] unless keys instanceof Array
    unsubscribemsgids = []
    publisher.register address, address
    for key in keys
      do (key) ->
        msgid = cuid()
        unsubscribemsgids.push msgid
        data =
          keys: keys
          address: advertise
        send address, msgid, ['_unsubscribe'], data
    unsubscribemsgids

  removedestination: (address) ->
    publisher.register address, address
    msgid = cuid()
    data = address: advertise
    send address, msgid, ['_removedestination'], data
    msgid

  drain: (cb) ->
    if incoming.length() is 0 and outgoing.length() is 0
      async.delay cb
      return
    _ondrained.push cb

  close: ->
    return if _fin
    _fin = yes
    publisher.close()
    receiver.close()
    subscriptions.close()
    incoming.close()
    outgoing.close()

  # surface some hub methods
  every: hub.every
  once: hub.once
  any: hub.any
  all: hub.all
