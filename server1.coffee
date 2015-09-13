Bus = require './bus'
bus = Bus
  bind: process.argv[2]
  datadir: process.argv[3]

setInterval ->
  console.log 'CLOUDY'
  bus.publish 'weather update', 'CLOUDY'
, 1000

process.on 'SIGINT', ->
  bus.close()
  process.exit 0