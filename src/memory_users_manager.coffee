class @MemoryUsersManager
  constructor: () ->
    @users_list = {'/meta/subscribe': {}}

  subscribeUser: (message) ->
    @users_list['/meta/subscribe'] = {} unless @users_list['/meta/subscribe']?
    @users_list[message.channel] = {} unless @users_list[message.channel]?
    @users_list['/meta/subscribe'][message.clientId+''] = {user_id: message.ext.user_id, user_name: message.ext.user_name, avatar: message.ext.avatar}
    message

  addUserToChannel: (clientId, channel) ->
    @users_list[channel] = {} unless @users_list[channel]?
    @users_list[channel][clientId+''] = @users_list['/meta/subscribe'][clientId+'']
    @users_list[channel][clientId+'']['time'] = new Date().getTime()

  removeUserFromChannel: (clientId, channel) ->
    delete @users_list[channel][clientId+'']

  unsubscribeUser: (clientId) ->
    delete @users_list['/meta/subscribe'][clientId+'']

  usersInChannel: (channel) ->
    @users_list[channel]

  allUsers: () ->
    @users_list['/meta/subscribe']