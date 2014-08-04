_server = require './server'
_env    = require 'node-env-file'

_env '.env'

exports.start = (http_port) ->
  server = new _server.Server
  server.start http_port, ->
    # server.sanitizeIncomingMessages()
    # server.authenticateOnMetaSubscriptions()
    # server.maintainUserList()

@start()