// Generated by CoffeeScript 1.9.2
var _, address, addresses, args, cmds, command, datadir, err, fs, incoming, incoming_path, outgoing, outgoing_path, resolve, shulz, subscriptions, subscriptions_path, uniqueaddresses, usage, usage_error, waserror;

usage = "Usage: resolute [command]\n\nShow the status of a resolute data directory\n\nCommands:\n  status                  Show an overview\n  unlock                  Unlock all maps\n  keys                    Print a list of subscription keys\n  subscribers             Print a list of unique subscribers\n  incoming                Print all incoming messages\n  outgoing                Print all outgoing messages\n\nOptions:\n  -h                      Display this usage information\n  -v                      Display the version number\n";

process.on('uncaughtException', function(err) {
  console.error('Caught exception: ');
  console.error(err.stack);
  return process.exit(1);
});

usage_error = (function(_this) {
  return function(message) {
    console.error();
    console.error("  " + message);
    console.error();
    console.error(usage);
    return process.exit(1);
  };
})(this);

args = process.argv.slice(2);

if (args.length > 3) {
  return console.error(usage);
}

resolve = require('path').resolve;

shulz = require('shulz');

fs = require('fs');

datadir = process.cwd();

waserror = false;

subscriptions_path = resolve(datadir, './subscriptions.shulz');

if (!fs.existsSync(subscriptions_path)) {
  console.error("Cannot open " + subscriptions_path);
  waserror = true;
}

outgoing_path = resolve(datadir, './outgoing.shulz');

if (!fs.existsSync(outgoing_path)) {
  console.error("Cannot open " + outgoing_path);
  waserror = true;
}

incoming_path = resolve(datadir, './incoming.shulz');

if (!fs.existsSync(incoming_path)) {
  console.error("Cannot open " + incoming_path);
  waserror = true;
}

if (waserror) {
  process.exit(-1);
}

subscriptions = shulz.read(subscriptions_path);

outgoing = shulz.read(outgoing_path);

incoming = shulz.read(incoming_path);

uniqueaddresses = {};

for (_ in subscriptions) {
  addresses = subscriptions[_];
  for (address in addresses) {
    _ = addresses[address];
    uniqueaddresses[address] = true;
  }
}

cmds = {
  status: function() {
    console.log((Object.keys(subscriptions).length) + " keys");
    console.log((Object.keys(subscriptions).length) + " subscribers");
    console.log((Object.keys(outgoing).length) + " outgoing");
    return console.log((Object.keys(incoming).length) + " incoming");
  },
  unlock: function() {
    var i, len, path, pathstodelete, results;
    pathstodelete = [resolve(datadir, './subscriptions.shulz.lock'), resolve(datadir, './outgoing.shulz.lock'), resolve(datadir, './incoming.shulz.lock')];
    results = [];
    for (i = 0, len = pathstodelete.length; i < len; i++) {
      path = pathstodelete[i];
      if (fs.existsSync(path)) {
        console.log("Removed " + path);
        results.push(fs.unlinkSync(path));
      } else {
        results.push(void 0);
      }
    }
    return results;
  },
  keys: function() {
    var i, key, len, ref, results;
    ref = Object.keys(subscriptions);
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      key = ref[i];
      results.push(console.log(key));
    }
    return results;
  },
  subscribers: function() {
    var i, key, len, ref, results;
    ref = Object.keys(uniqueaddresses);
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      key = ref[i];
      results.push(console.log(key));
    }
    return results;
  },
  outgoing: function() {
    var key, results, value;
    results = [];
    for (key in outgoing) {
      value = outgoing[key];
      results.push(console.log(key + " => " + (JSON.stringify(value))));
    }
    return results;
  },
  incoming: function() {
    var key, results, value;
    results = [];
    for (key in incoming) {
      value = incoming[key];
      results.push(console.log(key + " => " + (JSON.stringify(value))));
    }
    return results;
  },
  '-h': function() {
    return console.log(usage);
  },
  '-v': function() {
    var pjson;
    pjson = require('../package.json');
    return console.log(pjson.version);
  }
};

command = args.length === 0 ? 'status' : args.shift();

try {
  if (cmds[command] != null) {
    return cmds[command]();
  }
} catch (_error) {
  err = _error;
  if (err instanceof ShulzMapBusy) {
    console.error(err.message);
    console.error();
  } else {
    console.error('Caught exception: ');
    console.error(err.stack);
  }
  process.exit(1);
}

usage_error(command + " is not a known shulz command");
