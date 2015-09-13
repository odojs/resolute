Bus = require './bus'
bus = Bus
  bind: process.argv[2]
  datadir: process.argv[3]

bus.subscribe 'tcp://127.0.0.1:12345', 'weather update'

bus.hub.every 'weather update', (p, cb) ->
  console.log p
  cb()

seensigint = no
process.on 'SIGINT', ->
  process.exit 0 if seensigint
  seensigint = yes
  bus.unsubscribe 'tcp://127.0.0.1:12345', 'weather update', ->
    bus.close()
    process.exit 0