http          = require 'http'
fs            = require 'fs'
url           = require 'url'
path          = require 'path'
faye          = require 'faye'
redis         = require 'faye-redis'
memory_users  = require './memory_users_manager'
redis_users   = require './redis_users_manager'
sanitize      = require('validator').sanitize
_tools        = require '../lib/tools.js'
_config       = require '../lib/config.js'

{EventEmitter} = require 'events'

class @Server extends EventEmitter
  constructor: () ->

  #Start HTTP Server async on localhost
  startHTTP: (http_port, callback) ->
    port = _config.port(http_port)

    # Handle non-Bayeux requests
    requestHandler = (request, response) ->
      uri = url.parse(request.url).pathname
      if uri == '/'
        response.writeHead(200, {'Content-Type': 'text/html'})
        response.write('Pictie socket server is on /bayeux ; faye client is on bayeux/client.js')
        response.end()
      else if (uri == '/messages')
        if request.method == 'POST'
          console.log("POST " + uri)
          body = ''
          request.on 'data', (data) ->
            body += data
            if body.length > 1e6
              request.connection.destroy()
          request.on 'end', ->
            post = JSON.parse(body)
            #write in the room
            json = JSON.stringify({message: {sender: post.sender, recipient: post.recipient, body: post.body}})
            response.writeHead(200, {'Content-Type': 'application/json', "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "X-Requested-With, Content-Type"})
            response.end(json)
        else
          response.writeHead(200, {'Content-Type': 'application/json', "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "X-Requested-With, Content-Type"})
          response.end()

    @httpServer = http.createServer requestHandler

    @httpServer.listen Number(port), ->
      # console.log "HTTP server started on port #{Number(port)}"
      callback()

  #Attach faye to HTTP server to handle bayeux requests
  attachFaye: (engine, db=null) ->
    if engine == 'redis'
      @engine         = 'redis'
      redis_url       = _config.redis_url()
      @bayeux         = new faye.NodeAdapter({  mount: '/bayeux', timeout: 20, engine: { type: redis, host: redis_url.hostname, port: parseInt(redis_url.port), password: redis_url.auth?.split(':').slice(-1)[0] }})
      @users_manager  = new redis_users.RedisUsersManager(db)
    else
      @engine         = 'memory'
      @bayeux         = new faye.NodeAdapter({  mount: '/bayeux', timeout: 20 })
      @users_manager  = new memory_users.MemoryUsersManager
    @bayeux.attach @httpServer

  # Sanitize message (no html or javascript code)
  sanitizeIncomingMessages: ->
    @bayeux.addExtension {
      incoming: (message, callback) ->
        if /chat/.test(message.channel) && message.data.message?
          message.data.message = sanitize(message.data.message).entityEncode()
        callback(message)
    }

  #Check token given by client equals hashing channel name with secret key
  authenticateOnMetaSubscriptions: ->
    @bayeux.addExtension {
      incoming: (message, callback) ->
        if message.channel == '/meta/subscribe'
          # Error if auth token cannot be retrieved or calculated
          unless (message.ext? and message.ext.authToken? and message.ext.group?)
            message.error = 'Cannot validate auth token'
            return callback(message)

          message.error = 'Invalid subscription auth token' if (_tools.encrypt_token("sparta/chat/#{message.ext.group}") != message.ext.authToken)

        callback(message)
    }

  #Keep a UserList up to date with Save User Info sent from client into users_list
  maintainUserList: ->
    @bayeux.addExtension {
      # console.log("adding extension")
      incoming: (message, callback) =>
        # Let non-subscribe messages through
        if message.channel == '/meta/subscribe'
          @users_manager.subscribeUser message, callback
        else
          callback(message)
    }

    @bayeux.bind 'subscribe', (clientId, channel) =>
      #Join system channel => add user to user_list & notify channel clients with new subscription
      # console.log "Client " + clientId + " entered room" + channel + " said maintainUserList"
      if /chat/.test(channel)
        @users_manager.addUserToChannel clientId, channel, =>
          @publish_new_user_list(channel, 'join', clientId)
        # console.log "content of users_list => "+JSON.stringify(users_list)
      if /presence/.test(channel)
        @users_manager.getConnectedFriends clientId, (connected_friends) =>
          @publish_connected_friends_list channel, connected_friends, () =>
            this.emit 'friendsListPublished' if _config.env.dev
          @publish_new_user_to_his_friends clientId, connected_friends, () =>
            this.emit 'friendsNotified' if _config.env.dev
      if /chat\/1to1___/.test(channel)
        @invite_other_user_to_1to1_chat clientId, channel


    @bayeux.bind 'unsubscribe', (clientId, channel) =>
      # console.log "Client " + clientId + " left room "+ channel
      #Leaving chat channel => Remove User from user_list
      if /chat/.test(channel)
        @users_manager.removeUserFromChannel clientId, channel, =>
          @publish_new_user_list(channel, 'leave', clientId)

    @bayeux.bind 'disconnect', (clientId) =>
      @users_manager.unsubscribeUser clientId, (disconnectedUsername, friendsToNotify) =>
        if disconnectedUsername && friendsToNotify.length > 0
          for friend in friendsToNotify
            @bayeux.getClient().publish "/presence/#{friend}", {
              evt:           'friend_leaved',
              friend_name:   disconnectedUsername
            }

  stop: ->
    @httpServer.close()

  publish_new_user_list: (channel, movement, clientId) ->
    @users_manager.usersInChannel channel, (users) =>
      @bayeux.getClient().publish channel, {
        evt:        movement,
        clientId:   clientId,
        user_list:  users
      }

  publish_connected_friends_list: (channel, friends, callback) ->
    @bayeux.getClient().publish channel, {
        evt:           'connected_friends',
        friends_list:  friends
      }
    callback()

  publish_new_user_to_his_friends: (clientId, friends, callback) ->
    @users_manager.getUserInfo clientId, (userInfo) =>
      for friend in friends
        @bayeux.getClient().publish "/presence/#{friend}", {
            evt:           'friend_joined',
            friend_name:   userInfo.user_name
          }
      callback()

  invite_other_user_to_1to1_chat: (clientId, channel) ->
    @users_manager.getUserInfo clientId, (userInfo) =>
      myName = userInfo.user_name
      friendName = channel.split('___').slice(-2).filter (name) =>
        name != myName
      @bayeux.getClient().publish "/presence/#{friendName}", {
          evt:           '1to1_chat_invite',
          invitor_name:   myName
        }