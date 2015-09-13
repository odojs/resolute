Bus = require './bus'
bus = Bus
  bind: process.argv[2]
  datadir: process.argv[3]

bus.subscribe 'tcp://127.0.0.1:12345', 'weather update'
bus.subscribe 'tcp://127.0.0.1:12346', 'weather update'

bus.hub.every 'weather update', (p, cb) ->
  console.log p
  cb()

setTimeout ->
  bus.unsubscribe 'tcp://127.0.0.1:12345', 'weather update'
  bus.unsubscribe 'tcp://127.0.0.1:12346', 'weather update'
, 10000

process.on 'SIGINT', ->
  bus.close()
  process.exit 0