'use strict';

express    = require 'express',
bodyParser = require 'body-parser',
morgan     = require 'morgan';

class @ExpressApp
  constructor: () ->
    @app = express()

  init:(bayeux) ->
    @app.use morgan()
    @app.use bodyParser()
    @app.use express.static(__dirname + '/public')

    @app.get '/', (req, res) ->
      res.send 'Pictie socket server is on /bayeux ; faye client is on bayeux/client.js'

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

    @app.use (req, res, next) ->
      res.send 404, 'Sorry cant find that!'

        # @bayeux.getClient().publish "/user/#{post.recipient}", { evt: 'message', message:   {sender: post.sender, recipient: post.recipient, body: post.body}}
        # json = JSON.stringify({message: {sender: post.sender, recipient: post.recipient, body: post.body}})
        # response.writeHead(200, {'Content-Type': 'application/json', "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "X-Requested-With, Content-Type"})
        # response.end(json)
      # bayeux.getClient().publish('/channel', {text: req.body.message})
      # res.send(200)