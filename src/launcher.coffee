_server = require '../lib/server.js'

exports.start = (http_port) ->
  server = new _server.Server
  server.startHTTP http_port, ->
    server.attachFaye('memory')
    # server.sanitizeIncomingMessages()
    # server.authenticateOnMetaSubscriptions()
    # server.maintainUserList()

@start()