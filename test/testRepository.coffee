path = require 'path'
exec = require('child_process').execSync

module.exports =
  class TestRepository
    isWindows = process.platform == 'win32'
    extension = if isWindows then '.ps1' else '.sh'

    constructor: (@scenario) ->

    init: ->
      if isWindows
        exec 'powershell -file ' + path.join __dirname, @scenario + extension + ' ' + @fullPath()
      else
        exec path.join __dirname, @scenario + extension + ' ' + @fullPath()

    fullPath: ->
      path.join __dirname, 'test_repo'

    destroy: ->
      if isWindows        
        exec 'powershell -command "remove-item -recurse -force ' + @fullPath() + '"'
      else
        exec 'rm -rf ' + @fullPath()
