redis   = require 'redis'
util    = require 'util'
_config = require '../lib/config.js'

{EventEmitter} = require 'events'

class @RedisUsersManager extends EventEmitter
  constructor: (db_client) ->
    @all_users_key = 'chat:all_users'
    @channel_users_prefix = 'chat:channel_users'
    @user_names_key = 'chat:user_names'
    @client_ids_key = 'chat:client_ids'
    @friends_key    = 'chat:friends'
    if db_client?
      @redis_client = db_client
    else
      redis_url = _config.redis_url()
      @redis_client = redis.createClient(parseInt(redis_url.port), redis_url.hostname)
      @redis_client.auth(redis_url.auth?.split(':').slice(-1)[0])
    @redis_client.on "error", (err) ->
      console.log("Error " + err)

  subscribeUser: (message, callback) ->
    user_data    = {user_id: message.ext.user_id, user_name: message.ext.user_name, avatar: message.ext.avatar}
    friends_data = message.ext.friends
    @storeUserData user_data, friends_data, message, () =>
      this.emit 'subscribeUserFinished' if _config.env.dev
      callback(message)

  addUserToChannel: (clientId, channel, callback) ->
    @redis_client.hget @all_users_key, "#{clientId}", (err, res) =>
      client_user_data = JSON.parse(res)
      client_user_data['time'] = new Date().getTime()
      @redis_client.hset "#{@channel_users_prefix}:#{channel}", "#{clientId}", JSON.stringify(client_user_data), (err, result) =>
        this.emit('addUserToChannelFinished') if _config.env.dev
        callback()

  removeUserFromChannel: (clientId, channel, callback) ->
    @redis_client.hdel ["#{@channel_users_prefix}:#{channel}", clientId], (err, result) =>
      this.emit 'removeUserFromChannelFinished' if _config.env.dev
      callback()

  unsubscribeUser: (clientId, callback) ->
    @redis_client.hget @all_users_key, "#{clientId}", (err, res) =>
      client_user_data = JSON.parse(res)
      if client_user_data
        username = client_user_data['user_name']
        @getConnectedFriends clientId, (connectedFriends) =>
          @removeClientData username, clientId, (notifyFriends) =>
            this.emit 'unsubscribeUserFinished' if _config.env.dev
            if notifyFriends
              callback(username, connectedFriends)
            else
              callback(null, [])
      else
        callback(null, [])

  usersInChannel: (channel, callback) ->
    @redis_client.hgetall "#{@channel_users_prefix}:#{channel}", (err, result) =>
      callback(result)

  allUsers: (callback) ->
    @redis_client.hgetall @all_users_key, (err, result) =>
      callback(result)

  usernamesInList: (usernames, callback) ->
    @redis_client.hmget @user_names_key, usernames, (err, result) =>
      callback(result.filter((e) -> return e))

  storeUserData: (userData, friendsData, message, callback) =>
    @redis_client.hget @client_ids_key, userData.user_name, (err, result) =>
      result ||= '[]'
      client_ids = JSON.parse(result)
      already_present = client_ids.filter((id) -> return id == message.clientId).length > 0
      multi = @redis_client.multi()
      multi.hset @all_users_key, "#{message.clientId}", JSON.stringify(userData)
      multi.hset @friends_key, "#{message.clientId}", JSON.stringify(friendsData)
      multi.hset @user_names_key, userData.user_name, userData.user_name
      if already_present
        multi.exec (err, result) =>
          callback()
      else
        client_ids.push(message.clientId)
        multi.hset @client_ids_key, userData.user_name, JSON.stringify(client_ids)
        multi.exec (err, result) =>
          callback()

  removeClientData: (userName, clientId, callback) ->
    @redis_client.hget @client_ids_key, userName, (err, result) =>
      client_ids = JSON.parse(result)
      multi = @redis_client.multi()
      multi.hdel [@all_users_key, clientId]
      multi.hdel [@friends_key, clientId]
      remaining_client_ids = client_ids.filter((e) -> return e != clientId)
      if remaining_client_ids.length == 0
        multi.hdel [@client_ids_key, userName]
        multi.hdel [@user_names_key, userName]
        multi.exec (err, result) =>
          if err
            callback(false)
          else
           callback(true)
      else
        multi.hset @client_ids_key, userName, JSON.stringify(remaining_client_ids)
        multi.exec (err, result) =>
          callback(false)

  getUserInfo: (clientId, callback) ->
    @redis_client.hget @all_users_key, clientId, (err, result) ->
      callback(JSON.parse(result))

  getUserFriends: (clientId, callback) ->
    @redis_client.hget @friends_key, clientId, (err, result) ->
      callback(JSON.parse(result))

  getConnectedFriends: (clientId, callback) ->
    @getUserFriends clientId, (friends) =>
      @usernamesInList friends, (connected_friends) =>
        callback(connected_friends)
