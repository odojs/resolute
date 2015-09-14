usage = """
Usage: resolute [command]

Show the status of a resolute data directory

Commands:
  status                  Show an overview
  unlock                  Unlock all maps
  keys                    Print a list of subscription keys
  subscribers             Print a list of unique subscribers
  incoming                Print all incoming messages
  outgoing                Print all outgoing messages

Options:
  -h                      Display this usage information
  -v                      Display the version number

"""

process.on 'uncaughtException', (err) ->
  console.error 'Caught exception: '
  console.error err.stack
  process.exit 1

# General purpose printing an error and usage
usage_error = (message) =>
  console.error()
  console.error "  #{message}"
  console.error()
  console.error usage
  process.exit 1

args = process.argv[2..]

return console.error usage if args.length > 3

resolve = require('path').resolve
shulz = require 'shulz'
fs = require 'fs'

datadir = process.cwd()

waserror = no
subscriptions_path = resolve datadir, './subscriptions.shulz'
unless fs.existsSync subscriptions_path
  console.error "Cannot open #{subscriptions_path}"
  waserror = yes
outgoing_path = resolve datadir, './outgoing.shulz'
unless fs.existsSync outgoing_path
  console.error "Cannot open #{outgoing_path}"
  waserror = yes
incoming_path = resolve datadir, './incoming.shulz'
unless fs.existsSync incoming_path
  console.error "Cannot open #{incoming_path}"
  waserror = yes
process.exit -1 if waserror

subscriptions = shulz.read subscriptions_path
outgoing = shulz.read outgoing_path
incoming = shulz.read incoming_path
uniqueaddresses = {}
for _, addresses of subscriptions
  for address, _ of addresses
    uniqueaddresses[address] = yes

cmds =
  status: ->
    console.log "#{Object.keys(subscriptions).length} keys"
    console.log "#{Object.keys(uniqueaddresses).length} subscribers"
    console.log "#{Object.keys(outgoing).length} outgoing"
    console.log "#{Object.keys(incoming).length} incoming"

  unlock: ->
    pathstodelete = [
      resolve datadir, './subscriptions.shulz.lock'
      resolve datadir, './outgoing.shulz.lock'
      resolve datadir, './incoming.shulz.lock'
    ]
    for path in pathstodelete
      if fs.existsSync path
        console.log "Removed #{path}"
        fs.unlinkSync path

  keys: ->
    for key in Object.keys subscriptions
      console.log key

  subscribers: ->
    for key in Object.keys uniqueaddresses
      console.log key

  outgoing: ->
    for key, value of outgoing
      console.log "#{key} => #{JSON.stringify value}"

  incoming: ->
    for key, value of incoming
      console.log "#{key} => #{JSON.stringify value}"

  '-h': ->
    console.log usage

  '-v': ->
    pjson = require '../package.json'
    console.log pjson.version

command = if args.length is 0
    'status'
  else
    args.shift()
try
  return cmds[command]() if cmds[command]?
catch err
  if err instanceof ShulzMapBusy
    console.error err.message
    console.error()
  else
    console.error 'Caught exception: '
    console.error err.stack
  process.exit 1
usage_error "#{command} is not a known shulz command"
