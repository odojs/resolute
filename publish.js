// Generated by CoffeeScript 1.9.2
var send;

send = require('./send');

module.exports = function(options) {
  var channels, closechanneliffinshed, interval, intervaltick, messages, removemessageifcomplete, retrytimedoutmessages, startifstopped, stoptickiffinished, timeout;
  if (options == null) {
    options = {};
  }
  interval = options.interval, timeout = options.timeout;
  if (interval == null) {
    interval = 5000;
  }
  if (timeout == null) {
    timeout = 5000;
  }
  channels = {};
  messages = {};
  intervaltick = null;
  retrytimedoutmessages = function() {
    var channel, channelstorecreate, completed, i, j, k, len, len1, len2, message, messagestoretry, msgid, name, now, ref, results;
    now = process.hrtime();
    console.log('RETRYING');
    messagestoretry = [];
    for (msgid in messages) {
      message = messages[msgid];
      if (!(message.started < now + timeout)) {
        continue;
      }
      messagestoretry.push(message);
    }
    channelstorecreate = [];
    for (i = 0, len = messagestoretry.length; i < len; i++) {
      message = messagestoretry[i];
      ref = message.channels;
      for (name in ref) {
        completed = ref[name];
        if (completed) {
          continue;
        }
        channelstorecreate.push(channels[name]);
      }
    }
    for (j = 0, len1 = channelstorecreate.length; j < len1; j++) {
      channel = channelstorecreate[j];
      channel.socket.close();
    }
    results = [];
    for (k = 0, len2 = messagestoretry.length; k < len2; k++) {
      message = messagestoretry[k];
      message.started = now;
      results.push((function() {
        var ref1, results1;
        ref1 = message.channels;
        results1 = [];
        for (name in ref1) {
          completed = ref1[name];
          if (completed) {
            continue;
          }
          channel = channels[name];
          results1.push(channel.socket.send(msgid, message.data));
        }
        return results1;
      })());
    }
    return results;
  };
  startifstopped = function() {
    if (intervaltick != null) {
      return;
    }
    return intervaltick = setInterval(retrytimedoutmessages, interval);
  };
  closechanneliffinshed = function(name, channel) {
    return;
    if (Object.keys(channel.messages).length === 0) {
      return channel.socket.close();
    }
  };
  removemessageifcomplete = function(msgid, message) {
    var callback, completed, i, len, name, ref, ref1;
    ref = message.channels;
    for (name in ref) {
      completed = ref[name];
      if (!completed) {
        return;
      }
    }
    ref1 = messages[msgid].callbacks;
    for (i = 0, len = ref1.length; i < len; i++) {
      callback = ref1[i];
      callback();
    }
    delete messages[msgid];
    console.log("FIN " + msgid);
    return stoptickiffinished();
  };
  stoptickiffinished = function() {
    if (Object.keys(messages).length === 0) {
      clearInterval(intervaltick);
      return intervaltick = null;
    }
  };
  return {
    register: function(name, addresses) {
      if (channels[name] != null) {
        channels[name].socket.connect(addresses);
        return;
      }
      return channels[name] = {
        socket: send(addresses, function(msgid) {
          var channel, message;
          channel = channels[name];
          if (channel != null) {
            delete channel.messages[msgid];
            closechanneliffinshed(name, channel);
          }
          message = messages[msgid];
          if ((message != null) && (message.channels[name] != null)) {
            message.channels[name] = true;
            return removemessageifcomplete(msgid, message);
          }
        }),
        messages: {}
      };
    },
    publish: function(msgid, data, names, oncomplete) {
      var callbacks, i, len, name;
      callbacks = [];
      if (oncomplete != null) {
        callbacks.push(oncomplete);
      }
      if (!(names instanceof Array)) {
        names = [names];
      }
      messages[msgid] = {
        started: process.hrtime(),
        data: data,
        callbacks: callbacks,
        channels: {}
      };
      for (i = 0, len = names.length; i < len; i++) {
        name = names[i];
        messages[msgid].channels[name] = false;
        channels[name].messages[msgid] = true;
        channels[name].socket.send(msgid, data);
      }
      return startifstopped();
    },
    close: function() {
      var _, channel;
      for (_ in channels) {
        channel = channels[_];
        channel.socket.close();
      }
      channels = {};
      return messages = {};
    }
  };
};
