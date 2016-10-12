path = require 'path'
fs = require 'fs'
exec = require('child_process').execSync

module.exports =
  class TestRepository
    isWindows = process.platform == 'win32'
    extension = if isWindows then '.ps1' else '.sh'

    constructor: (@scenario, @repoDir = 'test_repo') ->

    init: ->
      if @exists()
        @destroy()

      command = undefined
      fullScenario = path.join __dirname, @scenario + extension
      if isWindows
        command = 'powershell -file ' + fullScenario + ' ' + '"' + @fullPath() + '"'
      else
        command = fullScenario + ' "' + @fullPath() + '"'
      exec command

    fullPath: ->
      path.join __dirname, @repoDir

    exists: () ->
      fs.existsSync(@fullPath())

    destroy: ->
      command = undefined
      if isWindows
        command = 'powershell -command "remove-item -recurse -force \'' + @fullPath() + '\'"'
      else
        command = 'rm -rf "' + @fullPath() + '"'
        command += '; rm -rf "' + @fullPath() + ' symlink"'
      exec command
