class @MemoryUsersManager
  constructor: () ->
    @users_list = {'/meta/subscribe': {}}

  subscribeUser: (message) ->
    console.log('in subscribe user' + JSON.stringify(message))
    @users_list['/meta/subscribe']                     = {} unless @users_list['/meta/subscribe']?
    # @users_list[message.channel]                        = {} unless @users_list[message.channel]?
    # @users_list['/meta/subscribe'][message.clientId+''] = {userId: message.ext.userId, avatar: message.ext.avatar}
    @users_list['/meta/subscribe'][message.ext.userId] = {} if !@users_list['/meta/subscribe'][message.ext.userId]?
    @users_list['/meta/subscribe'][message.ext.userId][message.clientId+''] = {pushPlatform: message.ext.pushPlatform, pushToken: message.ext.pushToken }

    message

  unsubscribeUser: (clientId) ->
    # delete @users_list['/meta/subscribe'][clientId+'']
    console.log('in unsubscribe user for ' + clientId)
    for key, val of @users_list['/meta/subscribe']
      delete @users_list['/meta/subscribe'][key][clientId+''] if @users_list['/meta/subscribe'][key][clientId+'']?

  # addUserToChannel: (clientId, channel) ->
  #   @users_list[channel]                      = {} unless @users_list[channel]?
  #   @users_list[channel][clientId+'']         = @users_list['/meta/subscribe'][clientId+'']
  #   @users_list[channel][clientId+'']['time'] = new Date().getTime()

  # removeUserFromChannel: (clientId, channel) ->
  #   delete @users_list[channel][clientId+'']


  # usersInChannel: (channel) ->
  #   @users_list[channel]

  allUsers: () ->
    @users_list['/meta/subscribe']