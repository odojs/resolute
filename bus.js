// Generated by CoffeeScript 1.9.2
var Hub, Publish, Receive, async, cuid, mkdirp, resolve, shulz;

cuid = require('cuid');

async = require('odo-async');

Publish = require('./publish');

Receive = require('./receive');

shulz = require('shulz');

Hub = require('odo-hub');

resolve = require('path').resolve;

mkdirp = require('mkdirp');

module.exports = function(options) {
  var _, _subscribe, _unsubscribe, address, addresses, advertise, bind, datadir, envelope, exec, hub, i, incoming, len, outgoing, publisher, receiver, ref, ref1, ref2, ref3, replayincoming, replayoutgoing, send, subscriptions;
  advertise = options.advertise;
  if (advertise == null) {
    advertise = options.bind;
  }
  bind = options.bind;
  datadir = resolve(process.cwd(), options.datadir);
  mkdirp.sync(datadir);
  hub = Hub.create();
  publisher = Publish();
  incoming = shulz.open(resolve(datadir, './incoming.shulz'));
  exec = function(envelope, cb) {
    var fn, i, key, len, ref, tasks;
    tasks = [];
    ref = envelope.keys;
    fn = function(key) {
      return tasks.push(function(cb) {
        return hub.emit(key, envelope.data, cb);
      });
    };
    for (i = 0, len = ref.length; i < len; i++) {
      key = ref[i];
      fn(key);
    }
    return async.parallel(tasks, cb);
  };
  replayincoming = [];
  ref = incoming.all();
  for (_ in ref) {
    envelope = ref[_];
    replayincoming.push(envelope);
  }
  async.delay(function() {
    var i, len, results;
    results = [];
    for (i = 0, len = replayincoming.length; i < len; i++) {
      envelope = replayincoming[i];
      results.push((function(envelope) {
        return exec(envelope, function() {
          return incoming.clear(envelope.id);
        });
      })(envelope));
    }
    return results;
  });
  receiver = Receive(bind, function(envelope, done) {
    envelope = JSON.parse(envelope.toString());
    incoming.set(envelope.id, envelope);
    async.delay(function() {
      return exec(envelope, function() {
        return incoming.clear(envelope.id);
      });
    });
    return done();
  });
  subscriptions = shulz.open(resolve(datadir, './subscriptions.shulz'));
  ref1 = subscriptions.all();
  for (_ in ref1) {
    addresses = ref1[_];
    for (address in addresses) {
      _ = addresses[address];
      publisher.register(address, address);
    }
  }
  _subscribe = function(key, address) {
    var subs;
    subs = subscriptions.get(key);
    if (subs == null) {
      subs = {};
    }
    subs[address] = true;
    subscriptions.set(key, subs);
    return publisher.register(address, address);
  };
  _unsubscribe = function(key, address) {
    var subs;
    subs = subscriptions.get(key);
    if (subs == null) {
      subs = {};
    }
    delete subs[address];
    return subscriptions.set(key, subs);
  };
  hub.every('_subscribe', function(m, cb) {
    var i, key, len, ref2;
    ref2 = m.keys;
    for (i = 0, len = ref2.length; i < len; i++) {
      key = ref2[i];
      _subscribe(key, m.address);
    }
    return cb();
  });
  hub.every('_unsubscribe', function(m, cb) {
    var i, key, len, ref2;
    ref2 = m.keys;
    for (i = 0, len = ref2.length; i < len; i++) {
      key = ref2[i];
      _unsubscribe(key, m.address);
    }
    return cb();
  });
  outgoing = shulz.open(resolve(datadir, './outgoing.shulz'));
  replayoutgoing = [];
  ref2 = outgoing.all();
  for (_ in ref2) {
    envelope = ref2[_];
    replayoutgoing.push(envelope);
    ref3 = envelope.addresses;
    for (i = 0, len = ref3.length; i < len; i++) {
      address = ref3[i];
      publisher.register(address, address);
    }
  }
  async.delay(function() {
    var j, len1, results;
    results = [];
    for (j = 0, len1 = replayoutgoing.length; j < len1; j++) {
      envelope = replayoutgoing[j];
      results.push((function(envelope) {
        var message;
        message = JSON.stringify(envelope);
        return publisher.publish(envelope.id, message, envelope.addresses, function() {
          return outgoing.clear(envelope.id);
        });
      })(envelope));
    }
    return results;
  });
  send = function(addresses, msgid, keys, data) {
    var message;
    envelope = {
      id: msgid,
      keys: keys,
      addresses: addresses,
      sent: new Date(),
      data: data
    };
    outgoing.set(msgid, envelope);
    message = JSON.stringify(envelope);
    return publisher.publish(msgid, message, addresses, function() {
      return outgoing.clear(msgid);
    });
  };
  return {
    publish: function(keys, data) {
      var j, key, len1, msgid, subs;
      if (!(keys instanceof Array)) {
        keys = [keys];
      }
      addresses = {};
      for (j = 0, len1 = keys.length; j < len1; j++) {
        key = keys[j];
        subs = subscriptions.get(key);
        if (subs == null) {
          continue;
        }
        for (address in subs) {
          _ = subs[address];
          addresses[address] = true;
        }
      }
      addresses = Object.keys(addresses);
      msgid = cuid();
      if (addresses.length === 0) {
        return msgid;
      }
      send(addresses, msgid, keys, data);
      return msgid;
    },
    send: function(key, data, address) {
      var msgid;
      publisher.register(address, address);
      msgid = cuid();
      send([address], msgid, [key], data);
      return msgid;
    },
    subscribe: function(address, keys, cb) {
      var fn, j, key, len1, subscribemsgids, tasks;
      if (!(keys instanceof Array)) {
        keys = [keys];
      }
      tasks = [];
      subscribemsgids = [];
      publisher.register(address, address);
      fn = function(key) {
        var data, msgid;
        msgid = cuid();
        subscribemsgids.push(msgid);
        data = {
          keys: keys,
          address: advertise
        };
        return tasks.push(function(cb) {
          return send(address, msgid, ['_subscribe'], data, cb);
        });
      };
      for (j = 0, len1 = keys.length; j < len1; j++) {
        key = keys[j];
        fn(key);
      }
      async.parallel(tasks, function() {
        if (cb != null) {
          return async.delay(cb);
        }
      });
      return subscribemsgids;
    },
    unsubscribe: function(address, keys, cb) {
      var fn, j, key, len1, tasks, unsubscribemsgids;
      if (!(keys instanceof Array)) {
        keys = [keys];
      }
      tasks = [];
      unsubscribemsgids = [];
      publisher.register(address, address);
      fn = function(key) {
        var data, msgid;
        msgid = cuid();
        unsubscribemsgids.push(msgid);
        data = {
          keys: keys,
          address: advertise
        };
        return tasks.push(function(cb) {
          return send(address, msgid, ['_unsubscribe'], data, cb);
        });
      };
      for (j = 0, len1 = keys.length; j < len1; j++) {
        key = keys[j];
        fn(key);
      }
      async.parallel(tasks, function() {
        if (cb != null) {
          return async.delay(cb);
        }
      });
      return unsubscribemsgids;
    },
    close: function() {
      publisher.close();
      receiver.close();
      subscriptions.close();
      incoming.close();
      return outgoing.close();
    },
    every: hub.every,
    once: hub.once,
    any: hub.any,
    all: hub.all
  };
};
