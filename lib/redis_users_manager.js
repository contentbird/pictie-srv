// Generated by CoffeeScript 1.3.3
(function() {
  var EventEmitter, redis, util, _config,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  redis = require('redis');

  util = require('util');

  _config = require('../lib/config.js');

  EventEmitter = require('events').EventEmitter;

  this.RedisUsersManager = (function(_super) {

    __extends(RedisUsersManager, _super);

    function RedisUsersManager(db_client) {
      this.storeUserData = __bind(this.storeUserData, this);

      var redis_url, _ref;
      this.all_users_key = 'chat:all_users';
      this.channel_users_prefix = 'chat:channel_users';
      this.user_names_key = 'chat:user_names';
      this.client_ids_key = 'chat:client_ids';
      this.friends_key = 'chat:friends';
      if (db_client != null) {
        this.redis_client = db_client;
      } else {
        redis_url = _config.redis_url();
        this.redis_client = redis.createClient(parseInt(redis_url.port), redis_url.hostname);
        this.redis_client.auth((_ref = redis_url.auth) != null ? _ref.split(':').slice(-1)[0] : void 0);
      }
      this.redis_client.on("error", function(err) {
        return console.log("Error " + err);
      });
    }

    RedisUsersManager.prototype.subscribeUser = function(message, callback) {
      var friends_data, user_data,
        _this = this;
      user_data = {
        user_id: message.ext.user_id,
        user_name: message.ext.user_name,
        avatar: message.ext.avatar
      };
      friends_data = message.ext.friends;
      return this.storeUserData(user_data, friends_data, message, function() {
        if (_config.env.dev) {
          _this.emit('subscribeUserFinished');
        }
        return callback(message);
      });
    };

    RedisUsersManager.prototype.addUserToChannel = function(clientId, channel, callback) {
      var _this = this;
      return this.redis_client.hget(this.all_users_key, "" + clientId, function(err, res) {
        var client_user_data;
        client_user_data = JSON.parse(res);
        client_user_data['time'] = new Date().getTime();
        return _this.redis_client.hset("" + _this.channel_users_prefix + ":" + channel, "" + clientId, JSON.stringify(client_user_data), function(err, result) {
          if (_config.env.dev) {
            _this.emit('addUserToChannelFinished');
          }
          return callback();
        });
      });
    };

    RedisUsersManager.prototype.removeUserFromChannel = function(clientId, channel, callback) {
      var _this = this;
      return this.redis_client.hdel(["" + this.channel_users_prefix + ":" + channel, clientId], function(err, result) {
        if (_config.env.dev) {
          _this.emit('removeUserFromChannelFinished');
        }
        return callback();
      });
    };

    RedisUsersManager.prototype.unsubscribeUser = function(clientId, callback) {
      var _this = this;
      return this.redis_client.hget(this.all_users_key, "" + clientId, function(err, res) {
        var client_user_data, username;
        client_user_data = JSON.parse(res);
        if (client_user_data) {
          username = client_user_data['user_name'];
          return _this.getConnectedFriends(clientId, function(connectedFriends) {
            return _this.removeClientData(username, clientId, function(notifyFriends) {
              if (_config.env.dev) {
                _this.emit('unsubscribeUserFinished');
              }
              if (notifyFriends) {
                return callback(username, connectedFriends);
              } else {
                return callback(null, []);
              }
            });
          });
        } else {
          return callback(null, []);
        }
      });
    };

    RedisUsersManager.prototype.usersInChannel = function(channel, callback) {
      var _this = this;
      return this.redis_client.hgetall("" + this.channel_users_prefix + ":" + channel, function(err, result) {
        return callback(result);
      });
    };

    RedisUsersManager.prototype.allUsers = function(callback) {
      var _this = this;
      return this.redis_client.hgetall(this.all_users_key, function(err, result) {
        return callback(result);
      });
    };

    RedisUsersManager.prototype.usernamesInList = function(usernames, callback) {
      var _this = this;
      return this.redis_client.hmget(this.user_names_key, usernames, function(err, result) {
        return callback(result.filter(function(e) {
          return e;
        }));
      });
    };

    RedisUsersManager.prototype.storeUserData = function(userData, friendsData, message, callback) {
      var _this = this;
      return this.redis_client.hget(this.client_ids_key, userData.user_name, function(err, result) {
        var already_present, client_ids, multi;
        result || (result = '[]');
        client_ids = JSON.parse(result);
        already_present = client_ids.filter(function(id) {
          return id === message.clientId;
        }).length > 0;
        multi = _this.redis_client.multi();
        multi.hset(_this.all_users_key, "" + message.clientId, JSON.stringify(userData));
        multi.hset(_this.friends_key, "" + message.clientId, JSON.stringify(friendsData));
        multi.hset(_this.user_names_key, userData.user_name, userData.user_name);
        if (already_present) {
          return multi.exec(function(err, result) {
            return callback();
          });
        } else {
          client_ids.push(message.clientId);
          multi.hset(_this.client_ids_key, userData.user_name, JSON.stringify(client_ids));
          return multi.exec(function(err, result) {
            return callback();
          });
        }
      });
    };

    RedisUsersManager.prototype.removeClientData = function(userName, clientId, callback) {
      var _this = this;
      return this.redis_client.hget(this.client_ids_key, userName, function(err, result) {
        var client_ids, multi, remaining_client_ids;
        client_ids = JSON.parse(result);
        multi = _this.redis_client.multi();
        multi.hdel([_this.all_users_key, clientId]);
        multi.hdel([_this.friends_key, clientId]);
        remaining_client_ids = client_ids.filter(function(e) {
          return e !== clientId;
        });
        if (remaining_client_ids.length === 0) {
          multi.hdel([_this.client_ids_key, userName]);
          multi.hdel([_this.user_names_key, userName]);
          return multi.exec(function(err, result) {
            if (err) {
              return callback(false);
            } else {
              return callback(true);
            }
          });
        } else {
          multi.hset(_this.client_ids_key, userName, JSON.stringify(remaining_client_ids));
          return multi.exec(function(err, result) {
            return callback(false);
          });
        }
      });
    };

    RedisUsersManager.prototype.getUserInfo = function(clientId, callback) {
      return this.redis_client.hget(this.all_users_key, clientId, function(err, result) {
        return callback(JSON.parse(result));
      });
    };

    RedisUsersManager.prototype.getUserFriends = function(clientId, callback) {
      return this.redis_client.hget(this.friends_key, clientId, function(err, result) {
        return callback(JSON.parse(result));
      });
    };

    RedisUsersManager.prototype.getConnectedFriends = function(clientId, callback) {
      var _this = this;
      return this.getUserFriends(clientId, function(friends) {
        return _this.usernamesInList(friends, function(connected_friends) {
          return callback(connected_friends);
        });
      });
    };

    return RedisUsersManager;

  })(EventEmitter);

}).call(this);
