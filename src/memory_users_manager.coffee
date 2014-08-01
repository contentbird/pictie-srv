class @MemoryUsersManager
  constructor: () ->
    @users_list = {'/meta/subscribe': {}}

  subscribeUser: (message) ->
    console.log('MemoryUsersManager - Subscribing user' + JSON.stringify(message))
    @users_list['/meta/subscribe']                     = {} unless @users_list['/meta/subscribe']?
    # @users_list[message.channel]                        = {} unless @users_list[message.channel]?
    # @users_list['/meta/subscribe'][message.clientId+''] = {userId: message.ext.userId, avatar: message.ext.avatar}
    @users_list['/meta/subscribe'][message.ext.userId] = {'clients': {}, 'pushs': {}} if !@users_list['/meta/subscribe'][message.ext.userId]?
    @users_list['/meta/subscribe'][message.ext.userId]['clients'] = {}                if !@users_list['/meta/subscribe'][message.ext.userId]['clients']?
    @users_list['/meta/subscribe'][message.ext.userId]['clients'][message.clientId] = new Date().getTime()

    message

  unsubscribeUser: (clientId) ->
    # delete @users_list['/meta/subscribe'][clientId+'']
    console.log('MemoryUsersManager Unsubscribing user with clientId' + clientId)
    for userId, val of @users_list['/meta/subscribe']
      delete @users_list['/meta/subscribe'][userId]['clients'][clientId+''] if @users_list['/meta/subscribe'][userId]['clients'][clientId+'']?

  storePushInfo: (userId, pushProvider, pushToken) ->
    console.log("MemoryUsersManager - Storing #{pushProvider} token #{pushToken} for user #{userId}")
    @users_list['/meta/subscribe'][userId] = {'clients': {}, 'pushs': {}} if !@users_list['/meta/subscribe'][userId]?
    @users_list['/meta/subscribe'][userId]['pushs'] = {}                  if !@users_list['/meta/subscribe'][userId]['pushs']?
    @users_list['/meta/subscribe'][userId]['pushs'][pushProvider] = pushToken

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