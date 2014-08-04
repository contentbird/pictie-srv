'use strict';

express    = require 'express',
bodyParser = require 'body-parser',
morgan     = require 'morgan',
apn        = require 'apn';

class @ExpressApp
  constructor: () ->
    @app = express()

  init:(bayeux, users_manager) ->
    @app.use morgan()
    @app.use bodyParser()
    @app.use express.static(__dirname + '/public')

    @app.get '/', (req, res) ->
      res.send 'Pictie socket server is on /bayeux ; faye client is on bayeux/client.js'

    @app.get '/users', (req, res) ->
      res.json(users_manager.allUsers())

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
      users_manager.storePushInfo(req.body.userId, req.body.pushProvider, req.body.pushToken)
      res.json({'result': 'success'})

    @app.post '/push_test', (req, res) =>
      console.log("received post on /push_test with #{JSON.stringify(req.body)}")
      this.sendNotification users_manager, req.body.userId, req.body.message
      res.json({'result': 'success'})

    @app.use (req, res, next) ->
      res.send 404, 'Sorry cant find that!'

        # @bayeux.getClient().publish "/user/#{post.recipient}", { evt: 'message', message:   {sender: post.sender, recipient: post.recipient, body: post.body}}
        # json = JSON.stringify({message: {sender: post.sender, recipient: post.recipient, body: post.body}})
        # response.writeHead(200, {'Content-Type': 'application/json', "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "X-Requested-With, Content-Type"})
        # response.end(json)
      # bayeux.getClient().publish('/channel', {text: req.body.message})
      # res.send(200)

  sendNotification: (users_manager, userId, message) ->
    pushInfo = users_manager.retrievePushInfo(userId)
    console.log("pushInfo for userId #{userId}" + JSON.stringify(pushInfo))

    errorCB = (err, notification) ->
      console.log(err + ' :: ' + notification)

    successCB = (notification, device) ->
      console.log("notification #{JSON.stringify(notification)} transmitted to device #{JSON.stringify(device)}")

    if pushInfo['APNS']?
      token   = pushInfo['APNS']
      console.log("sending to token #{token}")
      options = {
        cert:          process.env.APN_CERT_PEM || "certs/apn_cert.pem", #as local .env does not support multilines env vars
        key:           process.env.APN_KEY_PEM  || "certs/apn_key.pem"   #as local .env does not support multilines env vars
        errorCallback: errorCB
      }
      apnConnection = new apn.Connection(options)

      apnConnection.on("transmissionError", errorCB)
      apnConnection.on("error", errorCB)
      apnConnection.on("transmitted", successCB)
      apnConnection.on "cacheTooSmall", (sizeDifference) ->
        console.log 'Your cache is too small'
      apnConnection.on "timeout", () ->
        console.log 'Timeout'
      apnConnection.on "disconnected", (openSockets) ->
        console.log 'Disconnected'
      apnConnection.on "connected", () ->
        console.log 'Connected'

      device        = new apn.Device(token)
      console.log("device is #{JSON.stringify(device)}")
      note          = new apn.Notification()
      note.expiry   = Math.floor(Date.now() / 1000) + 3600 # Expires 1 hour from now.
      note.badge    = 1
      note.sound    = "ping.aiff"
      note.alert    = "You have a new Pictie"
      note.payload  = {'messageFrom': message.sender, 'messageBody': message.body}

      apnConnection.pushNotification note, device
    else
      res.send "Only APNS notification supported"

    feedback = new apn.Feedback({
      "batchFeedback": true,
      "interval": 300
    })

    feedback.on "feedback", (devices) ->
      devices.forEach (item) ->
        # Do something with item.device and item.time;
        console.log("Device: " + item.device.toString('hex') + " has been unreachable, since: " + item.time)

