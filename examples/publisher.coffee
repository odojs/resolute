Bus = require '../bus'
bus = Bus
  bind: process.argv[2]
  datadir: process.argv[3]

weather = [
  'cloudy'
  'sunny'
  'overcast'
  'meatballs'
  'rainy'
]
interval = setInterval ->
  i = Math.floor Math.random() * weather.length
  console.log weather[i]
  bus.publish 'weather update', weather[i]
, 1000

exittimeout = null
process.on 'SIGINT', ->
  clearInterval interval
  close = ->
    clearTimeout exittimeout
    bus.close()
  exit = ->
    close()
    console.log 'Exiting immediately'
    process.exit 0
  exit() if exittimeout?
  exittimeout = setTimeout exit, 10000
  console.log 'Waiting for queues to empty.'
  console.log '(^C again to quit)'
  bus.drain close