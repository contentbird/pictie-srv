require 'mocha'
should    = require 'should'
request   = require 'request'
sinon     = require 'sinon'
_server   = require '../lib/server.js'
_tools    = require '../lib/tools.js'
faye      = require 'faye'
fs        = require 'fs'
redis     = require 'redis'
fakeredis = require 'fakeredis'

http      = require 'http'

describe 'Server', ->
  subject = new _server.Server

  createUserWithExtension = (num, Extension) =>
    user = new faye.Client(subject.bayeux._server)
    user.addExtension Extension
    user

  user_subscription = (user_client, room_url, callback, finish) =>
    sub = user_client.subscribe '/chat'+room_url, (message) ->
      callback(message)
    if subject.users_manager?
      conditions = 0
      subject.users_manager.once 'subscribeUserFinished', (params) ->
        conditions += 1 ; finish() if conditions == 2
      subject.users_manager.once 'addUserToChannelFinished', (params) ->
        conditions += 1 ; finish() if conditions == 2
    else
      finish()
    sub

  user_presence = (user_client, room_url, callback, finish) =>
    sub = user_client.subscribe room_url, (message) ->
      callback(message)
    conditions = 0
    subject.once 'friendsListPublished', (params) ->
      conditions += 1 ; finish() if conditions == 2
    subject.once 'friendsNotified', (params) ->
      conditions += 1 ; finish() if conditions == 2
    sub

  spyShouldReceiveCalls = (spy, calls) ->
    checkCall(true, spy, calls)

  spyShouldNotReceiveCalls = (spy, calls) ->
    checkCall(false, spy, calls)

  checkCall = (received, spy, calls) ->
    for call in calls
      call_params = Object.keys(call)
      spy.args.filter (x) =>
        result = true
        for key in call_params
          result = result && (x[0][key].toString() == call[key].toString())
        result
      .should.have.lengthOf((received ? 1 : 0), "Call #{JSON.stringify(call)} #{'not ' if received }present in #{JSON.stringify(spy.args)}")

  describe '#startHTTP', ->
    it 'respond 200 to http requests on given port number', (done) ->
      subject.startHTTP 5001, ->
        request 'http://localhost:5001', (err, res, body) ->
          should.not.exist(err)
          res.statusCode.should.equal 200
          body.should.equal "Quintonic chat is on /bayeux ; faye client is on bayeux/client.js"
          done()

    it 'with env var PORT existing, should start http server on this port', (done) ->
      @sandbox = sinon.sandbox.create()
      @sandbox.stub(process, 'env', {PORT: 5002})

      subject.startHTTP null, =>
        request 'http://localhost:5002', (err, res, body) =>
          should.not.exist(err)
          @sandbox.restore()
          done()

    it 'without env var PORT existing and port given, should start http server 5000 by default', (done) ->
      subject.startHTTP null, ->
        request 'http://localhost:5000', (err, res, body) ->
          should.not.exist(err)
          done()

    afterEach ->
      subject.stop()

  describe '#attachFaye', ->
    it 'respond 400 to non-faye http requests on /bayeux', (done) ->
      subject.startHTTP 5010, ->
        subject.attachFaye()
        request 'http://localhost:5010/bayeux', (err, res, body) ->
          should.not.exist(err)
          res.statusCode.should.equal 400
          body.should.equal "Bad request"
          done()

    afterEach ->
      subject.stop()

  describe '#sanitizeIncomingMessages', ->
    it 'should html encode data.message property of any incoming messages to /chat ', (done) ->
      subject.startHTTP 5020, ->
        subject.attachFaye()
        subject.sanitizeIncomingMessages()
        subject.bayeux.bind 'publish', (clientId, channel, data) ->
          data.message.should.equal "&lt;html&gt;my message&lt;/html&gt;"
          done()
        subject.bayeux.getClient().publish('/chat/any_channel', {message:  '<html>my message</html>'})

    afterEach ->
      subject.stop()

  describe 'authenticateOnMetaSubscriptions', ->
    cli_extension = (token) ->
      { outgoing: (message, callback) ->
          return callback(message) if (message.channel != '/meta/subscribe')
          message.ext = { authToken: _tools.encrypt_token(token), group: 'the_group'}
          callback(message)
      }

    startAttachAuthExecute = (port, function1, function2) ->
      subject.startHTTP port, ->
        subject.attachFaye()
        subject.authenticateOnMetaSubscriptions()
        function1() ; function2()

    it 'should trigger success callback when client subscribes with right token', (done) ->
      startAttachAuthExecute 5030, (-> subject.bayeux.getClient().addExtension(cli_extension('sparta/chat/the_group'))), ->
        subscription = subject.bayeux.getClient().subscribe '/chat/any_channel'
        subscription.callback -> done()
        subscription.errback (error) -> done(throw error)

    it 'should return an error message when client subscribes without authentication', (done) ->
      startAttachAuthExecute 5031, (-> ), ->
        subscription = subject.bayeux.getClient().subscribe '/chat/any_channel'
        subscription.callback -> done(throw 'Was suposed to fail')
        subscription.errback (error) -> error.message.should.equal 'Cannot validate auth token' ; done()

    it 'should return an error message when client subscribes without right token', (done) ->
      startAttachAuthExecute 5032, (-> subject.bayeux.getClient().addExtension(cli_extension('invalid_token'))), ->
        subscription = subject.bayeux.getClient().subscribe '/chat/any_channel'
        subscription.callback -> done(throw 'Was suposed to fail')
        subscription.errback (error) -> error.message.should.equal 'Invalid subscription auth token' ; done()

    afterEach ->
      subject.stop()


  describe '#maintainUserList', ->
    cli_extension = (userNum)->
      { outgoing: (message, callback) ->
          return callback(message) if (message.channel != '/meta/subscribe')
          message.ext = { group: 'nna_group', user_id: "#{userNum}", user_name: "user_#{userNum}", avatar: "avatar_#{userNum}.jpg", friends: ["friend#{userNum}1", "friend#{userNum}2"] }
          callback(message)
      }

    createUser = (num) => createUserWithExtension(num, cli_extension(num))

    startAttachAuthUserListExecute = (port, fToExec) ->
      subject.startHTTP port, ->
        subject.attachFaye('redis', fakeredis.createClient(port.toString()))
        subject.maintainUserList()
        subject.bayeux.getClient().addExtension(cli_extension(1))
        fToExec()

    describe 'given there are no users', ->
      it 'should have 0 users connected and no user_list', (done) ->
        startAttachAuthUserListExecute 5041, ->
          validAssertions = 0
          subject.users_manager.allUsers (result) ->
            should.not.exist(result)
            validAssertions += 1 ; done() if validAssertions == 2

          subject.users_manager.usernamesInList ['user_1', 'user_whatever'], (usernames) ->
            usernames.should.eql []
            validAssertions += 1 ; done() if validAssertions == 2

    describe 'given user_1 joins /room/1', ->
      before (done) ->
        startAttachAuthUserListExecute 5042, ->
          user_subscription subject.bayeux.getClient(), '/room/1', ->
            null
          , ->
            done()

      it 'should list 1 user total, and user_1 in /room/1', (done) ->
        user_1 = subject.bayeux.getClient()._clientId

        validAssertions = 0

        subject.users_manager.allUsers (all_users) ->
          Object.keys(all_users).length.should.equal 1
          all_users.should.have.property(user_1)
          JSON.parse(all_users[user_1]).should.have.property('user_id').with.equal('1')
          validAssertions += 1 ; done() if validAssertions == 3

        subject.users_manager.usersInChannel '/chat/room/1', (room1_users) ->
          Object.keys(room1_users).length.should.equal 1
          room1_users.should.have.property(user_1)
          JSON.parse(room1_users[user_1]).should.have.property('user_id').with.equal('1')
          validAssertions += 1 ; done() if validAssertions == 3

        subject.users_manager.usernamesInList ['user_1', 'user_whatever'], (usernames) ->
          usernames.should.eql ['user_1']
          validAssertions += 1 ; done() if validAssertions == 3

    describe 'when user_2 joins to room/2', ->
      user_2 = null
      before (done) ->
        startAttachAuthUserListExecute 5043, ->
          user_subscription subject.bayeux.getClient(), '/room/1', ->
            null
          , ->
            user_2 = createUser(2)
            user_subscription user_2, '/room/2', ->
              null
            , ->
              done()

      it 'should list 2 users total, 1 users in room/1 and 1 in room/2 ', (done) ->
        validAssertions = 0

        subject.users_manager.allUsers (all_users) ->
          Object.keys(all_users).length.should.equal 2
          all_users.should.have.property(user_2._clientId)
          JSON.parse(all_users[user_2._clientId]).should.have.property('user_id').with.equal('2')
          validAssertions += 1 ; done() if validAssertions == 4

        subject.users_manager.usersInChannel '/chat/room/1', (room1_users) ->
          Object.keys(room1_users).length.should.equal 1
          validAssertions += 1 ; done() if validAssertions == 4

        subject.users_manager.usersInChannel '/chat/room/2', (room2_users) ->
          Object.keys(room2_users).length.should.equal 1
          room2_users.should.have.property(user_2._clientId)
          JSON.parse(room2_users[user_2._clientId]).should.have.property('user_id').with.equal('2')
          validAssertions += 1 ; done() if validAssertions == 4

        subject.users_manager.usernamesInList ['user_1', 'user_2', 'user_whatever'], (usernames) ->
          usernames.should.eql ['user_1', 'user_2']
          validAssertions += 1 ; done() if validAssertions == 4

    describe 'when user_2 joins and leaves room/2', ->
      user_2 = null
      validAssertions = 0
      before (done) ->
        startAttachAuthUserListExecute 5044, ->
          user_subscription subject.bayeux.getClient(), '/room/1', ->
            null
          , ->
            user_2 = createUser(2)
            user_subscription user_2, '/room/2', ->
              null
            , ->
              done()

      it 'should list 2 users total on chat, 1 user in room/1 and 0 in room/2 ', (done) ->
        subject.bayeux._server._engine.unsubscribe user_2._clientId, '/chat/room/2' # user_2.unsubscribe or sub2.cancel() doesn't work here ? :(

        subject.users_manager.once 'removeUserFromChannelFinished', (params) ->
          subject.users_manager.allUsers (all_users) ->
            Object.keys(all_users).length.should.equal 2
            validAssertions += 1 ; done() if validAssertions == 3

          subject.users_manager.usersInChannel '/chat/room/1', (room1_users) ->
            Object.keys(room1_users).length.should.equal 1
            validAssertions += 1 ; done() if validAssertions == 3

          subject.users_manager.usersInChannel '/chat/room/2', (room2_users) ->
            should.not.exist(room2_users)
            validAssertions += 1 ; done() if validAssertions == 3

    describe 'when user_1 disconnects', (done) ->
      user_1 = null
      validAssertions = 0

      before (done) ->
        startAttachAuthUserListExecute 5045, ->
          user_1 = subject.bayeux.getClient()
          user_subscription user_1, '/room/1', ->
            null
          , ->
            # destroyClient forces server to disconnect AND remove user from all without delay (unlike engine.disconnect)
            subject.bayeux._server._engine.destroyClient user_1._clientId, ->
              done() #We wait for client to be destroyed, that means server has already removed users from channels, so no need to wait event removeUserFromChannelFinished in test

      it 'should list 0 users total, and still 0 users in room/1 and 0 in room/2 ', (done) ->
        subject.users_manager.usersInChannel '/chat/room/1', (room1_users) ->
          should.not.exist(room1_users)
          validAssertions += 1 ; done() if validAssertions == 4

        subject.users_manager.usersInChannel '/chat/room/2', (room2_users) ->
          should.not.exist(room2_users)
          validAssertions += 1 ; done() if validAssertions == 4

        subject.users_manager.once 'unsubscribeUserFinished', (params) ->
          subject.users_manager.allUsers (all_users) ->
            should.not.exist(all_users)
            validAssertions += 1 ; done() if validAssertions == 4

          subject.users_manager.usernamesInList ['user_1', 'user_2', 'user_whatever'], (usernames) ->
            usernames.should.eql []
            validAssertions += 1 ; done() if validAssertions == 4

    describe 'when user_1 connects twice (with 2 differents clients)', (done) ->
      user_1bis = null
      validAssertions = 0

      before (done) ->
        startAttachAuthUserListExecute 5046, ->
          user_subscription subject.bayeux.getClient(), '/room/1', ->
            null
          , ->
            user_1bis = createUser(1)
            user_subscription user_1bis, '/room/2', ->
              null
            , ->
              done()

      it 'should list 2 users total, still 1 users in room/1 and 1 username', (done) ->
        subject.users_manager.allUsers (all_users) ->
          Object.keys(all_users).length.should.equal 2 #because there are 2 different clientId
          validAssertions += 1 ; done() if validAssertions == 3

        subject.users_manager.usersInChannel '/chat/room/1', (room1_users) ->
          Object.keys(room1_users).length.should.equal 1
          validAssertions += 1 ; done() if validAssertions == 3

        subject.users_manager.usernamesInList ['user_1', 'user_2', 'user_whatever'], (usernames) ->
          usernames.should.eql ['user_1']
          validAssertions += 1 ; done() if validAssertions == 3

    describe 'when user_1 connects twice and then disconnects from second client', (done) ->
      user_1bis = null
      validAssertions = 0

      before (done) ->
        startAttachAuthUserListExecute 5047, ->
          user_subscription subject.bayeux.getClient(), '/room/1', ->
            null
          , ->
            user_1bis = createUser(1)
            user_subscription user_1bis, '/room/2', ->
              null
            , ->
              done()

      it 'there should still be user_1 in usernames', (done) ->
        subject.bayeux._server._engine.destroyClient user_1bis._clientId, ->
          null

        subject.users_manager.once 'unsubscribeUserFinished', (params) ->
          subject.users_manager.allUsers (all_users) ->
            Object.keys(all_users).length.should.equal 1
            validAssertions += 1 ; done() if validAssertions == 2

          subject.users_manager.usernamesInList ['user_1', 'user_1bis', 'user_whatever'], (usernames) ->
            usernames.should.eql ['user_1']
            validAssertions += 1 ; done() if validAssertions == 2

    afterEach ->
      subject.stop()

  describe '#notifyClients', ->
    sandbox = sinon.sandbox.create()

    cli_extension = (userNum)->
      { outgoing: (message, callback) ->
          return callback(message) if (message.channel != '/meta/subscribe')
          message.ext = { group: 'nna_group', user_id: "#{userNum}", user_name: "user_#{userNum}", avatar: "avatar_#{userNum}.jpg", friends: ["friend#{userNum}1", "friend#{userNum}2"]}
          callback(message)
      }

    createUser = (num) => createUserWithExtension(num, cli_extension(num))

    startAttachAuthNotify = (port, fToExec) ->
      subject.startHTTP port, ->
        subject.attachFaye('redis', fakeredis.createClient(port.toString()))
        subject.maintainUserList()
        subject.bayeux.getClient().addExtension(cli_extension(1))
        fToExec()

    describe 'given user_1 and user_2 in chat room /chat/room/1', =>
      user_1_callback_spy = sandbox.spy()
      user_2_callback_spy = sandbox.spy()
      user_1 = user_2 = user_3 = null
      sub2 = null

      before (done) ->
        startAttachAuthNotify 5050, =>
          user_1 = subject.bayeux.getClient()
          user_subscription user_1, '/room/1', user_1_callback_spy, ->
            user_2 = createUser(2)
            sub2 = user_subscription user_2, '/room/1', user_2_callback_spy, ->
              done()

      it 'when user_3 subscribes to room/1, user_1 and user_2 receive a join evt', (done) ->
        user_3 = createUser(3)
        user_subscription user_3, '/room/1', ->
          null
        , ->
          setTimeout ->
            spyShouldReceiveCalls user_1_callback_spy, [ {evt: 'join', clientId: user_1._clientId},
                                                         {evt: 'join', clientId: user_2._clientId},
                                                         {evt: 'join', clientId: user_3._clientId} ]

            spyShouldReceiveCalls user_2_callback_spy, [ {evt: 'join', clientId: user_2._clientId},
                                                         {evt: 'join', clientId: user_3._clientId} ]

            done()
          , 100 #increased delay due to redis backend end

      it 'when user_2 unsubscribes from room/1, user_1 receive a leave evt', (done) ->
        sub2.cancel()
        setTimeout ->
          spyShouldReceiveCalls user_1_callback_spy, [ {evt: 'leave', clientId: user_2._clientId}]
          done()
        , 200

      it 'when user_2 disconnects, user_1 receive a leave evt', (done) ->
        user_2.disconnect()
        setTimeout ->
          spyShouldReceiveCalls user_1_callback_spy, [ {evt: 'leave', clientId: user_2._clientId}]

          done()
        , 200

      after ->
        user_1_callback_spy.reset()
        user_2_callback_spy.reset()

  describe 'maintainFriendsList and invite to 1to1 chat', ->

    friendsForUser = (user_num) ->
      if user_num == 1
        f = ['user_2']
      if user_num == 2
        f = ['user_1', 'user_3']
      if user_num == 3
        f = ['user_2']
      f

    cli_extension = (userNum) ->
      { outgoing: (message, callback) ->
          return callback(message) if (message.channel != '/meta/subscribe')
          message.ext = { group: 'nna_group', user_id: "#{userNum}", user_name: "user_#{userNum}", avatar: "avatar_#{userNum}.jpg", friends: friendsForUser(userNum) }
          callback(message)
      }

    createUser = (num) => createUserWithExtension(num, cli_extension(num))

    startAttachAuthUserListExecute = (port, fToExec) ->
      subject.startHTTP port, ->
        subject.attachFaye('redis', fakeredis.createClient(port.toString()))
        subject.maintainUserList()
        subject.bayeux.getClient().addExtension(cli_extension(1))
        fToExec()

    sandbox = sinon.sandbox.create()

    describe 'given user_1 user_2 and user_3 joins the chat and subscribe to their presence channel', =>
      user_1_callback_spy = sandbox.spy()
      user_2_callback_spy = sandbox.spy()
      user_3_callback_spy = sandbox.spy()
      user_1 = user_2 = user_3 = null

      before (done) ->
        startAttachAuthUserListExecute 5060, =>
          user_1 = subject.bayeux.getClient()
          user_presence user_1, '/presence/user_1', user_1_callback_spy, ->
            user_2 = createUser(2)
            user_presence user_2, '/presence/user_2', user_2_callback_spy, ->
              user_3 = createUser(3)
              user_presence user_3, '/presence/user_3', user_3_callback_spy, ->
                done()

      it 'everybody gets notified of his friends presence', (done) ->
        setTimeout ->

          spyShouldReceiveCalls user_1_callback_spy, [ {evt: 'connected_friends', friends_list: []},
                                                       {evt: 'friend_joined', friend_name: 'user_2'} ]

          spyShouldNotReceiveCalls user_1_callback_spy, [ {evt: 'friend_joined', friend_name: 'user_3'} ]

          spyShouldReceiveCalls user_2_callback_spy, [ {evt: 'connected_friends', friends_list: ['user_1']},
                                                       {evt: 'friend_joined', friend_name: 'user_3'} ]

          spyShouldReceiveCalls user_3_callback_spy, [ {evt: 'connected_friends', friends_list: ['user_2']} ]

          done()
        , 200

      it 'when user_3 disconnects his friends get notified', (done) ->
        user_3.disconnect()
        setTimeout ->
          spyShouldNotReceiveCalls user_1_callback_spy, [ {evt: 'friend_leaved', friend_name: 'user_3'} ]

          spyShouldReceiveCalls user_2_callback_spy, [ {evt: 'friend_leaved', friend_name: 'user_3'} ]

          done()
        , 400

      it 'when user 1 joins 1to1 chat with user_2, user_2 receives an invitation to chat on his presence channel', (done) ->
        user_subscription user_1, '/1to1___user_1___user_2', ->
          null
        , ->
          setTimeout ->
            spyShouldReceiveCalls user_2_callback_spy, [ {evt: '1to1_chat_invite', invitor_name: 'user_1'} ]

            spyShouldNotReceiveCalls user_3_callback_spy, [ {evt: '1to1_chat_invite', invitor_name: 'user_1'} ]

            done()
          , 100

      after ->
        user_1_callback_spy.reset()
        user_2_callback_spy.reset()
        user_3_callback_spy.reset()