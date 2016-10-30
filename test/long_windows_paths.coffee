require 'coffee-script/register'
require './fakeWindow'
HgRepository = require '../lib/hg-repository'
TestRepository = require './testRepository'
assert = require('chai').assert
path = require 'path'
exec = require('child_process').execSync

describe 'In a repository with a really long path', ->
  testRepo = new TestRepository path.parse(__filename).name
  repo = null
  before ->
    testRepo.init()

    isWindows = process.platform == 'win32'
    unless isWindows
      this.skip()
      return

  beforeEach ->
    repo = new HgRepository (testRepo.fullPath())

  it 'should still return isPathIgnored true', ->
    ignored_file = path.join testRepo.fullPath(), 'ignored_file'
    repo.refreshStatus().then ->
      assert.equal(repo.isPathIgnored(ignored_file), true)

  after ->
    command = 'dir \'' + testRepo.fullPath() + '\\subDir*\' | rename-item -NewName a'
    command = 'powershell -command "' + command + '"'
    exec command
    testRepo.destroy()
