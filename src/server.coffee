'use strict';

http          = require 'http',
faye          = require 'faye',
_app          = require './app',
_memory_users = require './memory_users_manager',
_redis_users  = require './redis_users_manager',
_push         = require './push_service'

class @Server
  constructor: (config) ->
    @config       = config
    @app          = new _app.ExpressApp
    @httpServer   = http.createServer @app.app

    this.attachFaye()
    this.maintainUserList()
    this.initPushService()
    this.initApp()

  start: (http_port, cb) =>
    @httpServer.listen Number(@config.port(http_port)), ->
      cb()

  attachFaye: (engine, db=null) ->
    if engine == 'redis'
      @engine         = 'redis'
      redis_url       = _config.redis_url()
      @bayeux         = new faye.NodeAdapter({  mount: '/bayeux', timeout: 20, engine: { type: redis, host: redis_url.hostname, port: parseInt(redis_url.port), password: redis_url.auth?.split(':').slice(-1)[0] }})
      @users_manager  = new _redis_users.RedisUsersManager(db)
    else
      @engine         = 'memory'
      @bayeux         = new faye.NodeAdapter({  mount: '/bayeux', timeout: 20 })
      @users_manager  = new _memory_users.MemoryUsersManager
    @bayeux.attach @httpServer

  initPushService: () ->
    @push = new _push.PushService(@users_manager)

  initApp: () ->
    @app.init(@bayeux, @users_manager, @push)

    #Keep a UserList up to date with Save User Info sent from client into users_list
  maintainUserList: ->
    @bayeux.addExtension {
      incoming: (message, callback) =>
        if message.channel == '/meta/subscribe'
          console.log("subscription coming: #{JSON.stringify(message)}");
          @users_manager.subscribeUser message, callback
        else
          # Let non-subscribe messages through
          callback(message)
    }

    @bayeux.bind 'disconnect', (clientId) =>
      console.log("disconnected client #{clientId}")
      @users_manager.unsubscribeUser clientId, () ->
        console.log("client #{clientId} unsubscribed")

  stop: ->
    @httpServer.close()