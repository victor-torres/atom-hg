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

  describe 'with a modified file', ->
    modifiedStatus = 1024
    modified_file = path.join testRepo.fullPath(), 'modified_file'

    it 'should count status as modified', ->
      assert.equal repo.isStatusModified(modifiedStatus), true

    it 'should return status staged', ->
      assert.equal repo.isStatusStaged(modifiedStatus), true

    it 'should return path staged', ->
      assert.equal repo.isPathStaged(modified_file), true

    it 'should return path modified', ->
      assert.equal repo.isPathModified(modified_file), true

    it 'should return cached path status modified', ->
      repo.refreshStatus().then ->
        assert.equal repo.getCachedPathStatus(modified_file), modifiedStatus

  describe 'with a tracked file', ->
    clean_file = path.join testRepo.fullPath(), 'clean_file'
    it 'should return isPathIgnored false', ->
      repo.refreshStatus().then ->
        assert.equal(repo.isPathIgnored(clean_file), false)

    it 'should return isPathStaged true', ->
      repo.refreshStatus().then ->
        assert.equal(repo.isPathStaged(clean_file), true)

  describe 'with an untracked file', ->
    untrackedStatus = 128
    untracked_file = path.join testRepo.fullPath(), 'untracked_file'
    it 'should return status not staged', ->
      assert.equal repo.isStatusStaged(untrackedStatus), false

    it 'should return isPathStaged false', ->
      repo.refreshStatus().then ->
        assert.equal(repo.isPathStaged(untracked_file), false)

  after ->
    testRepo.destroy()
