receive = require '../receive'

addresses = process.argv.slice 2

receive addresses, (msg, done) ->
  console.log msg.toString()
  done()