# Async zeromq publish
# Use with receive
# Will retry until it gets a response

send = require './send'

module.exports = (options) ->
  options ?= {}
  { interval, timeout } = options
  interval ?= 5000
  timeout ?= 5000

  channels = {}
  messages = {}

  # health
  intervaltick = null
  retrytimedoutmessages = ->
    now = process.hrtime()
    console.log 'RETRYING'
    # messages to retry
    messagestoretry = {}
    for msgid, message of messages
      continue unless message.started < now + timeout
      messagestoretry[msgid] = message
    # recreate zeromq sockets so we don't flood the buffer with dups
    channelstorecreate = []
    for msgid, message of messagestoretry
      for name, completed of message.channels
        continue if completed
        channelstorecreate.push channels[name]
    for channel in channelstorecreate
      channel.socket.close()
    for msgid, message of messagestoretry
      message.started = now
      for name, completed of message.channels
        continue if completed
        channel = channels[name]
        channel.socket.send msgid, message.data
  startifstopped = ->
    return if intervaltick?
    intervaltick = setInterval retrytimedoutmessages, interval
  closechanneliffinshed = (name, channel) ->
    if Object.keys(channel.messages).length is 0
      channel.socket.close()
  removemessageifcomplete = (msgid, message) ->
    for name, completed of message.channels
      return unless completed
    callback() for callback in messages[msgid].callbacks
    delete messages[msgid]
    console.log "FIN #{msgid}"
    stoptickiffinished()
  stoptickiffinished = ->
    if Object.keys(messages).length is 0
      clearInterval intervaltick
      intervaltick = null

  register: (name, addresses) ->
    if channels[name]?
      channels[name].socket.connect addresses
      return
    channels[name] =
      socket: send addresses, (msgid) ->
        channel = channels[name]
        if channel?
          delete channel.messages[msgid]
          closechanneliffinshed name, channel
        message = messages[msgid]
        if message? and message.channels[name]?
          message.channels[name] = yes
          removemessageifcomplete msgid, message
      messages: {}

  publish: (msgid, data, names, oncomplete) ->
    callbacks = []
    callbacks.push oncomplete if oncomplete?
    names = [names] unless names instanceof Array
    messages[msgid] =
      started: process.hrtime()
      data: data
      callbacks: callbacks
      channels: {}
    for name in names
      messages[msgid].channels[name] = no
      channels[name].messages[msgid] = yes
      channels[name].socket.send msgid, data
    startifstopped()

  close: ->
    channel.socket.close() for _, channel of channels
    channels = {}
    messages = {}
