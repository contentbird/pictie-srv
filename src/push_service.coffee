apn = require 'apn'

class @PushService
  constructor: (usersManager) ->
    options = {
        cert:          process.env.APN_CERT_PEM || "certs/apn_cert.pem", #as local .env does not support multilines env vars
        key:           process.env.APN_KEY_PEM  || "certs/apn_key.pem"   #as local .env does not support multilines env vars
        errorCallback: errorCB
      }
    @usersManager = usersManager

    @apnConnection = new apn.Connection(options)

    errorCB = (err, notification) ->
      console.log(err + ' :: ' + notification)

    successCB = (notification, device) ->
      console.log("notification #{JSON.stringify(notification)} transmitted to device #{JSON.stringify(device)}")

    @apnConnection.on("transmissionError", errorCB)
    @apnConnection.on("error", errorCB)
    @apnConnection.on("transmitted", successCB)
    @apnConnection.on "cacheTooSmall", (sizeDifference) ->
      console.log 'Your cache is too small'
    @apnConnection.on "timeout", () ->
      console.log 'Timeout'
    @apnConnection.on "disconnected", (openSockets) ->
      console.log 'Disconnected'
    @apnConnection.on "connected", () ->
      console.log 'Connected'

    @feedback = new apn.Feedback({
      "batchFeedback": true,
      "interval": 300
    })

    @feedback.on "feedback", (devices) ->
      devices.forEach (item) ->
        # Do something with item.device and item.time;
        console.log("Device: " + item.device.toString('hex') + " has been unreachable, since: " + item.time)

  sendNotification: (userId, message) ->
    pushInfo = @usersManager.retrievePushInfo(userId)
    console.log("pushInfo for userId #{userId}" + JSON.stringify(pushInfo))

    if pushInfo['APNS']?
      token   = pushInfo['APNS']
      console.log("sending to token #{token}")

      device        = new apn.Device(token)
      console.log("device is #{JSON.stringify(device)}")
      note          = new apn.Notification()
      note.expiry   = Math.floor(Date.now() / 1000) + 3600 # Expires 1 hour from now.
      note.badge    = 1
      note.sound    = "ping.aiff"
      note.alert    = "You have a new Pictie from #{message.sender}"
      note.payload  = {'messageFrom': message.sender, 'messageBody': message.body}

      @apnConnection.pushNotification note, device
    else
      res.send "Only APNS notification supported"