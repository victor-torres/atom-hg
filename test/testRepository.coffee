path = require 'path'
process = require 'child_process'

module.exports =
  class TestRepository
    constructor: (@scenario) ->

    init: ->
      process.execSync path.join __dirname, @scenario + '.sh' + ' ' + @fullPath()

    fullPath: ->
      path.join __dirname, 'test_repo'

    destroy: ->
      process.execSync 'rm -rf ' + @fullPath()
