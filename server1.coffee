Bus = require './bus'

addresses = process.argv.slice 2
publicaddress = addresses[0]
addresses = addresses.slice 1

bus = Bus publicaddress, addresses

setInterval ->
  bus.publish 'weather update', 'CLOUDY'
, 1000