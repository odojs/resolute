Bus = require '../bus'
bus = Bus
  bind: process.argv[2]
  datadir: process.argv[3]

bus.subscribe 'tcp://127.0.0.1:12345', 'weather update'

bus.every 'weather update', (p, cb) ->
  console.log p
  cb()

exittimeout = null
process.on 'SIGINT', ->
  close = ->
    clearTimeout exittimeout
    bus.close()
  exit = ->
    close()
    process.exit 0
  exit() if exittimeout?
  exittimeout = setTimeout exit, 10000
  console.log 'Waiting for queues to empty.'
  console.log '(^C again to quit)'
  bus.unsubscribe 'tcp://127.0.0.1:12345', 'weather update'
  bus.drain close