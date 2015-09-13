cuid = require 'cuid'
async = require 'odo-async'
Publish = require './publish'
Receive = require './receive'
shulz = require 'shulz'
Hub = require 'odo-hub'
resolve = require('path').resolve
mkdirp = require 'mkdirp'

module.exports = (options) ->
  advertise = options.advertise
  advertise ?= options.bind
  bind = options.bind
  datadir = resolve process.cwd(), options.datadir

  mkdirp.sync datadir

  hub = Hub.create()

  publisher = Publish()
  incoming = shulz.open resolve datadir, './incoming.shulz'

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
  receiver = Receive bind, (envelope, done) ->
    envelope = JSON.parse envelope.toString()
    incoming.set envelope.id, envelope
    # TODO: make this repeatable, trottleable, parallelisable, etc.
    async.delay ->
      exec envelope, ->
        incoming.clear envelope.id
    done()

  # persistent subscriber store
  subscriptions = shulz.open resolve datadir, './subscriptions.shulz'
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

  hub.every '_subscribe', (m, cb) ->
    for key in m.keys
      _subscribe key, m.address
    cb()
  hub.every '_unsubscribe', (m, cb) ->
    for key in m.keys
      _unsubscribe key, m.address
    cb()

  outgoing = shulz.open resolve datadir, './outgoing.shulz'

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
          incoming.clear envelope.id

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
      cb()

  publish: (keys, data, cb) ->
    keys = [keys] unless keys instanceof Array
    addresses = {}
    for key in keys
      subs = subscriptions.get key
      continue if !subs?
      for address, _ of subs
        addresses[address] = yes
    addresses = Object.keys addresses
    msgid = cuid()
    if addresses.length is 0
      async.delay cb if cb?
      return msgid
    send addresses, msgid, keys, data, ->
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
        data =
          keys: keys
          address: advertise
        tasks.push (cb) ->
          send address, msgid, ['_subscribe'], data, cb
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
        data =
          keys: keys
          address: advertise
        tasks.push (cb) ->
          send address, msgid, ['_unsubscribe'], data, cb
    async.parallel tasks, ->
      async.delay cb if cb?
    unsubscribemsgids

  close: ->
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