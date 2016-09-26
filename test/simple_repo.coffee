require 'coffee-script/register'
require './fakeWindow'
HgRepository = require '../lib/hg-repository'
TestRepository = require './testRepository'
assert = require('chai').assert
path = require 'path'

describe 'In a repo with some ignored files', ->
  testRepo = new TestRepository path.parse(__filename).name
  repo = null
  before ->
    testRepo.init()

  beforeEach ->
    repo = new HgRepository testRepo.fullPath()

  describe 'with an ignored file', ->
    ignored_file = path.join testRepo.fullPath(), 'ignored_file'

    it 'should return isPathIgnored true', ->
      repo.refreshStatus().then ->
        assert.equal(repo.isPathIgnored(ignored_file), true)

    it 'should return getPathStatus 0', ->
      assert.equal(repo.getPathStatus(ignored_file), 0)

  describe 'with a tracked file', ->
    clean_file = path.join testRepo.fullPath(), 'clean_file'
    it 'should return isPathIgnored false', ->
      repo.refreshStatus().then ->
        assert.equal(repo.isPathIgnored(clean_file), false)

  after ->
    testRepo.destroy()
