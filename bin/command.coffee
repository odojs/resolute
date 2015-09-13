usage = """
Usage: resolute [datadir]
       resolute unlock

Show the status of a resolute data directory

Commands:
  unlock                  Unlock all maps

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
if args.length is 1
  if args[0] is 'unlock'
    pathstodelete = [
      resolve datadir, './subscriptions.shulz.lock'
      resolve datadir, './outgoing.shulz.lock'
      resolve datadir, './incoming.shulz.lock'
    ]
    for path in pathstodelete
      if fs.existsSync path
        console.log "Removed #{path}"
        fs.unlinkSync path
    process.exit 0
  datadir = resolve datadir, args[0]

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

console.log '# Keys'
for key in Object.keys subscriptions
  console.log "- #{key}"
console.log()

uniqueaddresses = {}
for _, addresses of subscriptions
  for address, _ of addresses
    uniqueaddresses[address] = yes
console.log '# Subscribers'
for key in Object.keys uniqueaddresses
  console.log "- #{key}"
console.log()

console.log "# #{Object.keys(outgoing).length} outgoing"
console.log "# #{Object.keys(incoming).length} incoming"