receive = require '../src/receive'

addresses = process.argv.slice 2

receive addresses, (msg, done) ->
  console.log msg.toString()
  setTimeout done, 7000