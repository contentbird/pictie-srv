_server = require './server'

exports.start = (http_port) ->
  server = new _server.Server
  server.start http_port, ->
    # server.sanitizeIncomingMessages()
    # server.authenticateOnMetaSubscriptions()
    # server.maintainUserList()

@start()