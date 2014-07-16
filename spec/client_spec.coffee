require 'mocha'
should  = require 'should'
sinon   = require 'sinon'
request = require 'request'
_client = require '../lib/client.js'
_server = require '../lib/server.js'
_tools  = require '../lib/tools.js'
faye    = require 'faye'


describe 'Client', ->
  before ->
    @subject  = new _client.Client
    @server   = new _server.Server

  describe '#constructor', ->

    it 'should create a faye client in .client and bind it to localhost:5000/bayeux by default', ->
      @subject.client.should.be.an.instanceof(faye.Client)
      @subject.client.endpoint.href.should.equal 'http://localhost:5000/bayeux'

    it 'should connect to given faye url and store given user_info', ->
      c = new _client.Client('http://my_url:my_port/faye', {user_id: 123, user_name: 'nicolas'})
      c.client.endpoint.href.should.equal 'http://my_url:my_port/faye'
      c.user_info.should.eql {user_id: 123, user_name: 'nicolas'}

  describe '#addUserInfoToMetaSubscriptions', ->
    beforeEach ->
      @client = new _client.Client(null, {user_id: 123, user_name: 'nicolas'})
      @client.addUserInfoToMetaSubscriptions()

    it 'should add user_info to outgoing messages when subscribing to /chat', (done) ->
      @server.startHTTP 5000, =>
        @server.attachFaye()
        @server.bayeux.addExtension {
          incoming: (message, callback) ->
            if message.channel == '/meta/subscribe'
              message.ext.user_info.should.eql {user_id: 123, user_name: 'nicolas'}
              done()
            callback(message)
        }
        @client.client.subscribe '/chat/room/1', (message) ->

    it 'should leave message unchanged when publishing to /chat channel', (done) ->
      @server.startHTTP 5000, =>
        @server.attachFaye()
        @server.bayeux.addExtension {
          incoming: (message, callback) ->
            if message.channel == '/chat/room/1'
              should.not.exist(message.ext)
              done()
            callback(message)
        }
        @client.client.subscribe '/chat/room/1', (message) ->
        @client.client.publish '/chat/room/1', {msg: 'Hello'}

    afterEach ->
      @server.stop()

  describe '#signOutgoingMetaSubscriptions', ->
    beforeEach ->
      @client = new _client.Client(null, null, 'group', 'token')
      @client.signOutgoingMetaSubscriptions()

    it 'should add an encrypted token and group to message when subscribing', (done) ->
      @server.startHTTP 5000, =>
        @server.attachFaye()
        @server.bayeux.addExtension {
          incoming: (message, callback) ->
            if message.channel == '/meta/subscribe'
              message.ext.group.should.equal 'group'
              message.ext.authToken.should.equal 'token'
              done()
            callback(message)
        }
        @client.client.subscribe '/chat/room/1', (message) ->

    it 'should leave message unchanged when publishing to /chat channel', (done) ->
      @server.startHTTP 5000, =>
        @server.attachFaye()
        @server.bayeux.addExtension {
          incoming: (message, callback) ->
            if message.channel == '/chat/room/1'
              should.not.exist(message.ext)
              done()
            callback(message)
        }
        @client.client.subscribe '/chat/room/1', (message) ->
        @client.client.publish '/chat/room/1', {msg: 'Hello'}

    afterEach ->
      @server.stop()

  describe '#notifyOnIncomingEvts', ->
    before ->
      @notify_spy = sinon.sandbox.create().spy()
      @client = new _client.Client
      @client.notifyOnIncomingEvts(@notify_spy)

    it 'should run given callback when message carries join or leave event', (done) ->
      @server.startHTTP 5000, =>
        @server.attachFaye()

        @client.client.receiveMessage {data: {evt: 'join', message: 'toto'}}
        @client.client.receiveMessage {data: {evt: 'leave', message: 'toto'}}

        setTimeout =>
          @notify_spy.calledTwice.should.be.true
          done()
        ,1

    it 'should not run given callback when message does not carry join or leave event in data', (done) ->
      @server.startHTTP 5000, =>
        @server.attachFaye()

        @client.client.receiveMessage {data: {some: 'join', message: 'toto'}}
        @client.client.receiveMessage {data: {username: 'nna', message: 'Iam talking to you'}}

        setTimeout =>
          @notify_spy.called.should.be.false
          done()
        ,1

    afterEach ->
      @notify_spy.reset()
      @server.stop()