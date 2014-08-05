// Generated by CoffeeScript 1.3.3
(function() {
  var apn;

  apn = require('apn');

  this.PushService = (function() {

    function PushService(usersManager) {
      var errorCB, options, successCB;
      options = {
        cert: process.env.APN_CERT_PEM || "certs/apn_cert.pem",
        key: process.env.APN_KEY_PEM || "certs/apn_key.pem",
        errorCallback: errorCB
      };
      this.usersManager = usersManager;
      this.apnConnection = new apn.Connection(options);
      errorCB = function(err, notification) {
        return console.log(err + ' :: ' + notification);
      };
      successCB = function(notification, device) {
        return console.log("notification " + (JSON.stringify(notification)) + " transmitted to device " + (JSON.stringify(device)));
      };
      this.apnConnection.on("transmissionError", errorCB);
      this.apnConnection.on("error", errorCB);
      this.apnConnection.on("transmitted", successCB);
      this.apnConnection.on("cacheTooSmall", function(sizeDifference) {
        return console.log('Your cache is too small');
      });
      this.apnConnection.on("timeout", function() {
        return console.log('Timeout');
      });
      this.apnConnection.on("disconnected", function(openSockets) {
        return console.log('Disconnected');
      });
      this.apnConnection.on("connected", function() {
        return console.log('Connected');
      });
      this.feedback = new apn.Feedback({
        "batchFeedback": true,
        "interval": 300
      });
      this.feedback.on("feedback", function(devices) {
        return devices.forEach(function(item) {
          return console.log("Device: " + item.device.toString('hex') + " has been unreachable, since: " + item.time);
        });
      });
    }

    PushService.prototype.sendNotification = function(userId, message) {
      var device, note, pushInfo, token;
      pushInfo = this.usersManager.retrievePushInfo(userId);
      console.log(("pushInfo for userId " + userId) + JSON.stringify(pushInfo));
      if (pushInfo['APNS'] != null) {
        token = pushInfo['APNS'];
        console.log("sending to token " + token);
        device = new apn.Device(token);
        console.log("device is " + (JSON.stringify(device)));
        note = new apn.Notification();
        note.expiry = Math.floor(Date.now() / 1000) + 3600;
        note.badge = 1;
        note.sound = "ping.aiff";
        note.alert = "You have a new Pictie from " + message.sender;
        note.payload = {
          'messageFrom': message.sender,
          'messageBody': message.body
        };
        return this.apnConnection.pushNotification(note, device);
      } else {
        return res.send("Only APNS notification supported");
      }
    };

    return PushService;

  })();

}).call(this);