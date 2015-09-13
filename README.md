# Resolute
Reliable messaging in Node.js

Resolute implements the servicebus pattern - publishing and subscribing to events and sending commands.

## Features
- Backed by [zeromq](http://zeromq.org/) dealer and router sockets.
- Reliable messaging
- At least once delivery
- Message order not guaranteed
- Automatic retries
- Brokerless publish and subscribe
- Send commands
- Disaster recovery tools

## Node.js is a perfect platform for a servicebus
The non-blocking single process model sidesteps many concurrency problems. Resolute is intended to be run inside the same process as your Node.js service or website. Each process runs a servicebus so there is no need for inter-process concurrency control for persistence.

The non-blocking nature of Node.js means we can perform atomic operations on the backing stores. We are also able to service requests while waiting for messages to send and be received.

## Resolute is persistent
Resolute stores a copy of all subscriptions, outgoing and incoming messages on disk, writing to these stores before applying any further action. Messages are only removed from the stores when their delivery has been guaranteed. Provided the filesystem is trustworthy and services can be restarted resolute guarantees at least once message delivery in a distributed system. Multiple copies of the same message may be sent during a disaster scenario so messages should be idempotent or not cause an issue if run twice or more.

Resolute expects a filesystem fsync to result in a disaster recoverable change. Network mounts and other exciting filesystems may not promise recoverable changes after an fsync. Resolute works best when working on a local harddrive.

## Disaster Recovery
Resolute includes a command line tool to help inspect the state of a servicebus. Subscriptions, outgoing and incoming stores are [shulz](https://github.com/metocean/shulz) hashmaps and can be administrated with the [shulz](https://www.npmjs.com/package/shulz) command line tool.

Shulz creates lock files along side the hashmaps to warn against more than once process accessing the same store. Shulz and [seuss](https://www.npmjs.com/package/seuss) expect to be the only process operating on their disk based storage.

If a servicebus process was not shut down correctly the lock files need to be removed before it can start again. If you are sure the process has failed run `resolute unlock` in the `datadir`. Once the lock files have been removed the process can be restarted. In an unlocked state stores can be administered to remove or update messages, adjust subscribers or purge and start the servicebus from scratch.

## Example scenario
You have two servers - a webserver hosting a website and a backend server that sends emails. In our scenario users sign up on the website and welcome emails are sent from the backend server to greet the new users. A business evaluation has indicated that users should still be able to sign up even if emails are not able to be sent. The welcome emails can queue until emails can be sent. Additionally the email service should stay running during a website outage as it also sends important emails from other systems.

Logically there may be several independent actions initiated whenever a user signs up to the website. We may want to add more actions for each user signup in the future. Architecturally it is easier if the webserver has no knowledge of the steps occuring after a user has signed up and the subscribing services register their interest in the `signup event`.

We require some sort of coordination between the webserver and the email service. Many message buses require a third server to broker the messages between webserver and email service. However now there is a third server that requires additional uptime guarantees. A more robust solution involves the webserver talking directly to the backend server. This pattern scales well and does not require a central broker that requires high uptime.

## Web -> Outgoing
Each step in the process needs a save state in case of power failure or other issue. We will start with the signup submit button. This button sends a post request to the Node.js webserver which may be running something like [expressjs](http://expressjs.com/). The hander for the post may update a database and perform other actions like validation. At some point it will want to publish a notification to anyone who is interested that a new user has signed up. This calls `resolute.publish` which writes synchronously to the harddrive and returns immediately. The expressjs handler can return a success message and the user is able to continue on with their actions. The webserver can crash any time after the publish has been written and the publish will be retried when the servicebus is restarted.

## Email Service -> Web
The email service knows it needs to receive messages from the website. It has an event key and the tcp host and port address of the website servicebus socket. To receive messages from the website the email service needs a servicebus. Each instance of resolute includes sending and receiving functionality. The email service sends a message using the normal resolute protocol to the website providing a return address. This message asks the website to subscribe the email service to all `signup events`. If the website servicebus is down the subscribtion message waits in the outgoing queue until it can be successfully delivered. The email service will only stop trying to send the subscription message once it has a successful reply from the website. Once subscribed the website knows every `signup event` needs to be sent to the email service.

## Outgoing
In a separate async thread the servicebus looks at the outgoing messages. For each message it looks at the subscriptions and works out how many destinations this message needs to be sent to. The message is only removed from the store when it has been successfully received by all subscribers. In a failure situation a message could be sent to three out of four subscribers before crashing. When restarting the message will attempt to send to the three subscribers again, along with re-attempting to send to the fourth subscriber. So the message is only removed once a reply is heard from all subscribers. The message will continue to attempt to send to any subscriber who is down, queuing the message.

## Incoming
When the email service receives the message it is written to disk and an acknowledgement is sent immediately. Shortening the time to acknowledgement helps the sending servicebus continue with other things.

## Incoming -> Processing
In a separate async thread the servicebus picks up messages on the incoming store and dispatches them to an internal hub. All subscribed methods are required to callback before the message is removed from the incoming store. If an error occurs or the process crashes the message will still be on the incoming store. In our scenario the sign up message is dispatched to the email handler which generates an email and connects to an smtp server to send the email. Once the smtp server has responded with success the handler calls done and the message is removed from the incoming queue.


## Future
- Dead letter queue for messages that fail repeatedly
- Max concurrency count for sending and processing. Currently outgoing messages and incoming messages are processed as fast as they can.


# Publisher
```js
var resolute = require 'resolute'
var bus = resolute({
    bind: 'tcp://127.0.0.1:12345',
    datadir: process.cwd()
});

setInterval(function() {
  console.log('CLOUDY');
  bus.publish('weather update', 'CLOUDY');
}, 1000);

process.on('SIGINT', function() {
  bus.close();
  process.exit(0);
});
```


# Subscriber
```js
var resolute = require 'resolute'
var bus = resolute({
    bind: 'tcp://127.0.0.1:54321',
    datadir: process.cwd()
});

bus.subscribe('tcp://127.0.0.1:12345', 'weather update');

bus.every('weather update', function(p, cb) {
  console.log(p);
  cb();
});

var seensigint = false;
process.on('SIGINT', function() {
  if (seensigint) {
    console.log('Exiting without confirming unsubscription');
    bus.close();
    process.exit(0);
  }
  seensigint = true;
  console.log('Attempting to unsubscribe');
  bus.unsubscribe('tcp://127.0.0.1:12345', 'weather update', function() {
    bus.close();
    process.exit(0);
  });
});
```


# Command line tool

```console
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

```
