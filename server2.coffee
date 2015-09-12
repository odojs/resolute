Bus = require './bus'

addresses = process.argv.slice 2
publicaddress = addresses[0]
addresses = addresses.slice 1

bus = Bus publicaddress, addresses
bus.subscribe 'tcp://127.0.0.1:12345', 'weather update'

bus.hub.every 'weather update', (p, cb) ->
  console.log p
  cb()

setTimeout ->
  bus.unsubscribe 'tcp://127.0.0.1:12345', 'weather update'
, 10000