url     = require('url')

exports.redis_url = ->
  url.parse(process.env.REDISTOGO_URL || 'redis://localhost:6379')

exports.port = (http_port) ->
  parseInt(process.env.PORT) || http_port || 5000

exports.env = { prod: (process.env.ENV == 'prod'), dev:  (process.env.ENV != 'prod') }