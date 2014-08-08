apn = require 'apn'
gcm = require 'node-gcm'

class @PushService
  constructor: (usersManager) ->
    @usersManager = usersManager

    apnOptions = {
      cert:          process.env.APN_CERT_PEM || "certs/apn_cert.pem", #as local .env does not support multilines env vars
      key:           process.env.APN_KEY_PEM  || "certs/apn_key.pem"   #as local .env does not support multilines env vars
      errorCallback: errorCB
    }

    @apnConnection = new apn.Connection(apnOptions)
    @gcmSender     = new gcm.Sender(process.env.GCM_API_KEY)

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

    notifTitle   = "You have a new Pictie from #{message.sender}"
    messageCount = 1
    extraParams  = { 'messageFrom': message.sender, 'messageBody': message.body }

    if pushInfo['APNS']?
      token         = pushInfo['APNS']

      device        = new apn.Device(token)
      note          = new apn.Notification()
      note.expiry   = Math.floor(Date.now() / 1000) + 3600 # Expires 1 hour from now.
      note.badge    = messageCount
      note.sound    = "ping.aiff"
      note.alert    = notifTitle
      note.payload  = extraParams

      @apnConnection.pushNotification note, device
    else
      token                 = pushInfo['GCM']
      extraParams.msgcnt    = messageCount
      extraParams.soundname = "beep.wav"
      extraParams.message   = notifTitle
      message = new gcm.Message({ data: extraParams })
      nbRetries = 3

      @gcmSender.send message, [token], nbRetries, (err, result) ->
        console.log(result);