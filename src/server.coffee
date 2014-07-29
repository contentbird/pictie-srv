'use strict';

http          = require 'http',
faye          = require 'faye';
_config       = require './config',
_app          = require './app',
_memory_users = require './memory_users_manager',
_redis_users  = require './redis_users_manager',

class @Server
  constructor: () ->

  startHTTP: (http_port, callback) =>
    port = _config.port(http_port)
    @app = new _app.ExpressApp
    @httpServer = http.createServer @app.app
    @httpServer.listen Number(port), ->
      # console.log "HTTP server started on port #{Number(port)}"
      callback()

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

  initApp: () ->
    @app.init(@bayeux)