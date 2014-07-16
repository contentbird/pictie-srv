faye    = require 'faye'
_tools  = require '../lib/tools.js'

class @Client
  constructor: (server_url, @user_info, @group, @authToken) ->
    url = server_url || 'http://localhost:5000/bayeux'
    @client = new faye.Client(url)

  addUserInfoToMetaSubscriptions: =>
    @client.addExtension { 
      outgoing: (message, callback) =>
        if message.channel == '/meta/subscribe'
          message.ext = {} unless message.ext?
          message.ext.user_info = @user_info
        callback(message)
    }

  signOutgoingMetaSubscriptions: =>
    @client.addExtension { 
      outgoing: (message, callback) =>
        if message.channel == '/meta/subscribe'
          message.ext = {} unless message.ext?
          message.ext.group = @group
          message.ext.authToken = @authToken
        callback(message)
    }

  notifyOnIncomingEvts: (notify) =>
    @client.addExtension { 
      incoming: (message, callback) ->
        if (message.data != undefined && (message.data.evt == 'join' || message.data.evt == 'leave'))
          notify() # notify but prevent the message from being received
        else callback(message) # Carry on and send the message to the client
    }
