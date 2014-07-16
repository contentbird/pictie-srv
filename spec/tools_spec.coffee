mocha    = require 'mocha'
should  = require 'should'
sinon   = require 'sinon'

Tools    = require '../lib/tools.js'

describe 'Tools', ->
  describe '#encrypt_token', ->
    it 'should return the given token encrypted using SHA1', ->
      Tools.encrypt_token('abc').should.equal('a9993e364706816aba3e25717850c26c9cd0d89d')