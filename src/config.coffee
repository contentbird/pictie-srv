_fs  = require 'fs'
_url = require 'url'
_env = require 'node-env-file'

_env '.env' if _fs.existsSync('.env')

exports.redis_url = ->
  _url.parse(process.env.REDISTOGO_URL)

exports.port = (http_port) ->
  parseInt(process.env.PORT) || http_port || 5000

exports.env = { prod: (process.env.ENV == 'prod'), dev:  (process.env.ENV != 'prod') }