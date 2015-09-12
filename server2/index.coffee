cuid = require 'cuid'
publish = require '../publish'



out = publish()
out.connect 'one', ['tcp://127.0.0.1:12345']
out.connect 'two', ['tcp://127.0.0.1:12346']

out.publish cuid(), 'Hello 1', ['one'], ->
  console.log 'Hello 1 COMPLETE'
out.publish cuid(), 'Hello 2', ['one', 'two'], ->
  console.log 'Hello 2 COMPLETE'
out.publish cuid(), 'Hello 3', ['two'], ->
  console.log 'Hello 3 COMPLETE'