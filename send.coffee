# Async zeromq message send
# Use with receive
# Does not gurantee anything

zmq = require 'zmq'

module.exports = (addresses, onreceipt) ->
  unless addresses instanceof Array
    addresses = [addresses]

  _addresses = {}
  for addr in addresses
    _addresses[addr] = yes

  socket = null
  startifstopped = ->
    return if socket?
    socket = zmq.socket 'dealer'
    for addr in Object.keys _addresses
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
  connect: (addresses) ->
    unless addresses instanceof Array
      addresses = [addresses]
    toconnect = []
    for addr in addresses
      continue if _addresses[addr]?
      _addresses[addr] = yes
      toconnect.push addr
    return if !socket?
    for addr in toconnect
      socket.connect addr
      console.log "ZMQ CONNECTED #{addr}"
  disconnect: (addresses) ->
    unless addresses instanceof Array
      addresses = [addresses]
    for addr in addresses
      continue if !_addresses[addr]?
      delete _addresses[addr]
      socket.disconnect addr
  close: ->
    return if !socket?
    socket.close()
    socket = null
    for addr in addresses
      console.log "ZMQ DISCONNECTED #{addr}"
