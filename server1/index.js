// Generated by CoffeeScript 1.9.2
var addresses, receive;

receive = require('../src/receive');

addresses = process.argv.slice(2);

receive(addresses, function(msg, done) {
  console.log(msg.toString());
  return setTimeout(done, 7000);
});
