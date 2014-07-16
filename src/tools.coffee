crypto        = require('crypto')

exports.encrypt_token = (token) ->
  crypto.createHash('sha1').update(token).digest('hex')