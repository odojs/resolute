// Generated by CoffeeScript 1.9.2
var references;

references = require('./referencecounter');

module.exports = function(bus, bindings) {
  var refs, subscriptions;
  if (bindings == null) {
    bindings = {};
  }
  subscriptions = {};
  refs = references();
  return {
    subscribe: function(key, cb) {
      return refs.ref(key, function() {
        var _, address, ref, results;
        subscriptions[key] = true;
        if (bindings[key] == null) {
          return;
        }
        ref = bindings[key];
        results = [];
        for (address in ref) {
          _ = ref[address];
          results.push(bus.subscribe(address, key));
        }
        return results;
      });
    },
    unsubscribe: function(key, cb) {
      return refs.unref(key, function() {
        var _, address, ref, results;
        delete subscriptions[key];
        if (bindings[key] == null) {
          return;
        }
        ref = bindings[key];
        results = [];
        for (address in ref) {
          _ = ref[address];
          results.push(bus.unsubscribe(address, key));
        }
        return results;
      });
    },
    bind: function(key, addresses) {
      var address, i, len, results;
      if (!(addresses instanceof Array)) {
        addresses = [addresses];
      }
      if (bindings[key] == null) {
        bindings[key] = {};
      }
      results = [];
      for (i = 0, len = addresses.length; i < len; i++) {
        address = addresses[i];
        if ((bindings[key][address] == null) && subscriptions[key]) {
          bus.subscribe(address, key);
        }
        results.push(bindings[key][address] = true);
      }
      return results;
    },
    unbind: function(key, addresses) {
      var address, i, len, results;
      if (!(addresses instanceof Array)) {
        addresses = [addresses];
      }
      if (bindings[key] == null) {
        return;
      }
      results = [];
      for (i = 0, len = addresses.length; i < len; i++) {
        address = addresses[i];
        if (bindings[key][address] && subscriptions[key]) {
          bus.unsubscribe(address, key);
        }
        results.push(delete bindings[key][address]);
      }
      return results;
    }
  };
};
