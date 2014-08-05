class @MemoryUsersManager
  constructor: () ->
    @users_list = {'/meta/subscribe': {}}

  subscribeUser: (message, callback) ->
    console.log('MemoryUsersManager - Subscribing user' + JSON.stringify(message))
    @users_list['/meta/subscribe'] = {} unless @users_list['/meta/subscribe']?
    # @users_list[message.channel]                        = {} unless @users_list[message.channel]?
    # @users_list['/meta/subscribe'][message.clientId+''] = {userId: message.ext.userId, avatar: message.ext.avatar}
    @users_list['/meta/subscribe'][message.ext.userId] = {'clients': {}, 'pushs': {}} if !@users_list['/meta/subscribe'][message.ext.userId]?
    @users_list['/meta/subscribe'][message.ext.userId]['clients'] = {}                if !@users_list['/meta/subscribe'][message.ext.userId]['clients']?
    @users_list['/meta/subscribe'][message.ext.userId]['clients'][message.clientId] = new Date().getTime()
    callback(message)

  unsubscribeUser: (clientId, callback) ->
    # delete @users_list['/meta/subscribe'][clientId+'']
    console.log('MemoryUsersManager Unsubscribing user with clientId' + clientId)
    for userId, val of @users_list['/meta/subscribe']
      delete @users_list['/meta/subscribe'][userId]['clients'][clientId+''] if @users_list['/meta/subscribe'][userId]['clients'][clientId+'']?
    callback

  storePushInfo: (userId, pushProvider, pushToken) ->
    console.log("MemoryUsersManager - Storing #{pushProvider} token #{pushToken} for user #{userId}")
    @users_list['/meta/subscribe'][userId] = {'clients': {}, 'pushs': {}} if !@users_list['/meta/subscribe'][userId]?
    @users_list['/meta/subscribe'][userId]['pushs'] = {}                  if !@users_list['/meta/subscribe'][userId]['pushs']?
    @users_list['/meta/subscribe'][userId]['pushs'][pushProvider] = pushToken

  retrievePushInfo: (userId) ->
    console.log("MemoryUsersManager - Retrieving pushInfo for user #{userId}")
    console.log(@users_list['/meta/subscribe'][userId]['pushs'])
    @users_list['/meta/subscribe'][userId]['pushs'] if @users_list['/meta/subscribe'][userId]?

  hasUserSubscribedClients: (userId) ->
    if @users_list['/meta/subscribe'][userId] && (Object.keys(@users_list['/meta/subscribe'][userId]['clients']).length > 0)
      true
    else
      false

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