'use strict';

express    = require 'express',
bodyParser = require 'body-parser',
morgan     = require 'morgan'

class @ExpressApp
  constructor: () ->
    @app  = express()

  init:(bayeux, usersManager, pushService) ->
    @app.use morgan()
    @app.use bodyParser()
    @app.use express.static(__dirname + '/public')

    @app.get '/', (req, res) ->
      res.send 'Pictie socket server is on /bayeux ; faye client is on bayeux/client.js'

    @app.get '/users', (req, res) ->
      res.json(usersManager.allUsers())

    @app.all '/messages', (req, res, next) ->
      res.header("Access-Control-Allow-Origin", "*")
      res.header("Access-Control-Allow-Headers", "X-Requested-With, Content-Type")
      next()

    @app.options '/messages', (req, res) ->
      res.end()

    @app.post '/messages', (req, res) ->
      message = {sender: req.body.sender, recipient: req.body.recipient, body: req.body.body}
      bayeux.getClient().publish "/user/#{req.body.recipient}", { evt: 'message', message: message }
      res.json(message)

    @app.post '/push_registration', (req, res) ->
      console.log("received post on /push_registration #{JSON.stringify(req.body)}")
      usersManager.storePushInfo(req.body.userId, req.body.pushProvider, req.body.pushToken)
      res.json({'result': 'success'})

    @app.post '/push_test', (req, res) =>
      console.log("received post on /push_test with #{JSON.stringify(req.body)}")
      pushService.sendNotification req.body.userId, req.body.message
      res.json({'result': 'success'})

    @app.use (req, res, next) ->
      res.send 404, 'Sorry cant find that!'