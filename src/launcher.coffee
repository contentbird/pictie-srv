_config = require './config',
_server = require './server'

exports.start = (http_port) ->
  server = new _server.Server(_config)
  server.start http_port, ->
    # server.sanitizeIncomingMessages()
    # server.authenticateOnMetaSubscriptions()
    # server.maintainUserList()

@start()