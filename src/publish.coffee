send = require '../src/send'

module.exports = (options) ->
  options ?= {}
  { interval, timeout } = options
  interval ?= 5000
  timeout ?= 5000

  channels = {}
  messages = {}

  # health
  tick = null
  check = ->
    now = process.hrtime()
    console.log 'RETRYING'
    # messages to retry
    for msgid, message of messages
      continue unless message.started < now + timeout
      message.started = now
      for name, completed of message.channels
        continue if completed
        channel = channels[name]
        channel.socket.send msgid, message.data
  startifstopped = ->
    return if tick?
    tick = setInterval check, interval
  closechanneliffinshed = (name, channel) ->
    if Object.keys(channel.messages).length is 0
      channel.socket.close()
  removemessageifcomplete = (msgid, message) ->
    for name, completed of message.channels
      return unless completed
    delete messages[msgid]
    console.log "FIN #{msgid}"
    stoptickiffinished()
  stoptickiffinished = ->
    if Object.keys(messages).length is 0
      clearInterval tick
      tick = null

  connect: (name, addresses) ->
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

  publish: (msgid, data, names) ->
    names = [names] unless names instanceof Array
    messages[msgid] =
      started: process.hrtime()
      data: data
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
