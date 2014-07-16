require 'mocha'
should  = require 'should'
sinon   = require 'sinon'

# _launcher  = require '../lib/launcher.js'

describe 'Launcher', ->
  describe '#start', ->
    # it 'should create, start a new httpServer, attach faye', ->
    #   _server    = require '../lib/server.js'
    #   @sandbox = sinon.sandbox.create()
    #   # @sandbox.stub(process, 'env', {PORT: 5002})

    #   @sandbox.mock(_server).expects("Server").once()

    #   # server_spy = sinon.stub(_server, 'Server')
    #   # new_server = sinon.stub(_server.Server.prototype, "new")
    #   # console.log new_server
    #   _launcher.start(5003)
    #   # console.log server_spy.called
    #   # server_spy.stubs
    #   # console.log server_spy.calledWithNew()

    #   # server = new _server.Server
    #   # # sinon.stub(Object.new).withArgs('_server.Server').returns(server)
    #   # console.log "server ==> #{server}"
    #   # mock = sinon.mock(server)
    #   # mock.expects("startHTTP").withExactArgs(5003).twice()
    #   # _launcher.start(5003)
    #   # mock.verify()
    #   # spy.called
    #   @sandbox.verify()