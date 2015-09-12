# Async zeromq message receive
# Use with send
# Does not gurantee anything

zmq = require 'zmq'
async = require 'odo-async'

module.exports = (addresses, onmessage) ->
  unless addresses instanceof Array
    addresses = [addresses]

  socket = zmq.socket 'router'
  tasks = []
  for addr in addresses
    do (addr) ->
      tasks.push (cb) ->
        socket.bind addr, (err) ->
          throw err if err?
          console.log "ZMQ BIND #{addr}"
          cb()

  async.series tasks, ->
    socket.on 'message', (id, _, msgid, data) ->
      onmessage data, -> socket.send [id, '', msgid]

  close: ->
    if socket?
      socket.close()
      socket = null