# Async zeromq message send
# Use with receive
# Does not gurantee anything

zmq = require 'zmq'

module.exports = (addresses, onreceipt) ->
  unless addresses instanceof Array
    addresses = [addresses]

  socket = null
  startifstopped = ->
    return if socket?
    socket = zmq.socket 'dealer'
    for addr in addresses
      socket.connect addr
      console.log "ZMQ CONNECTED #{addr}"
    socket.on 'message', (_, msgid) ->
      msgid = msgid.toString()
      console.log "ZMQ SENT #{msgid}"
      onreceipt msgid

  send: (msgid, data) ->
    startifstopped()
    console.log "ZMQ SENDING #{msgid}"
    socket.send ['', msgid, data]
  close: ->
    return if !socket?
    socket.close()
    socket = null
    for addr in addresses
      console.log "ZMQ DISCONNECTED #{addr}"
