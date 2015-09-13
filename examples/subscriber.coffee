Bus = require '../bus'
bus = Bus
  bind: process.argv[2]
  datadir: process.argv[3]

bus.subscribe 'tcp://127.0.0.1:12345', 'weather update'

bus.every 'weather update', (p, cb) ->
  console.log p
  cb()

seensigint = no
process.on 'SIGINT', ->
  if seensigint
    console.log 'Exiting without confirming unsubscription'
    bus.close()
    process.exit 0
  seensigint = yes
  console.log 'Attempting to unsubscribe'
  bus.unsubscribe 'tcp://127.0.0.1:12345', 'weather update', ->
    bus.close()
    process.exit 0