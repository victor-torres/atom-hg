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

   it 'should show a short-head with tags and bookmarks', (done) ->
     repo = new HgRepository testRepo.fullPath()
     repo.onDidChangeStatuses ->
       assert.equal(repo.shortHead, 'default:test-bookmark:test-tag,tip')
       done()
     repo.getShortHead(testRepo.fullPath())

  it 'should diff against "." by default', (done) ->
    modifiedFilePath = path.join testRepo.fullPath(), 'modified_file'
    expected =
      added: 0
      deleted: 0
    assert.deepEqual(repo.getDiffStats(modifiedFilePath), expected)

    repo.onDidChangeStatus ->
      expected =
        added: 2
        deleted: 0
      assert.deepEqual(repo.getDiffStats(modifiedFilePath), expected)
      done()

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

describe 'In a repo with spaces in the directory name', ->
  testRepo = new TestRepository path.parse(__filename).name, 'test repo'
  repo = null
  before ->
    testRepo.init()

  beforeEach ->
    repo = new HgRepository testRepo.fullPath()

  ###
  Currently any error in hg-stat commands is caught and console.error logged,
  but the promise is not rejected.
  So we're testing for this issue by side-effect,
  ideally we would just assert the promise resolved succesfully
  ###
  it 'should still return isPathIgnored true', ->
    ignored_file = path.join testRepo.fullPath(), 'ignored_file'
    repo.refreshStatus().then ->
      assert.equal(repo.isPathIgnored(ignored_file), true)

  after ->
    testRepo.destroy()

describe 'In a repo opened from a symbolic link', ->
  testRepo = new TestRepository path.parse(__filename).name
  repo = null
  before ->
    testRepo.init()

    isWindows = process.platform == 'win32'
    if isWindows
      this.skip()
      return

  beforeEach ->
    repo = new HgRepository (testRepo.fullPath() + ' symlink')

  it 'should still return isPathIgnored true with real path', ->
    # The path here does not include the 'symlink' suffix as tree-view and
    # git-diff don't seem to include it when calling our repository methods.
    # https://github.com/victor-torres/atom-hg/issues/18
    ignored_file = path.join testRepo.fullPath(), 'ignored_file'
    repo.refreshStatus().then ->
      assert.equal(repo.isPathIgnored(ignored_file), true)

  it 'should still return isPathIgnored true with symlink path', ->
    # The path here does not include the 'symlink' suffix as tree-view and
    # git-diff don't seem to include it when calling our repository methods.
    # https://github.com/victor-torres/atom-hg/issues/18
    ignored_file = path.join testRepo.fullPath() + ' symlink', 'ignored_file'
    repo.refreshStatus().then ->
      assert.equal(repo.isPathIgnored(ignored_file), true)

  after ->
    testRepo.destroy()

describe 'In a repo with a custom revision diff provider', ->
  testRepo = new TestRepository path.parse(__filename).name
  repo = null
  before ->
    testRepo.init()

  beforeEach ->
    repo = new HgRepository testRepo.fullPath(), diffRevisionProvider: ->
      'commit1'

  it 'should be able to diff against a provided revision', (done) ->
    modifiedFilePath = path.join testRepo.fullPath(), 'modified_file'

    expected =
      added: 0
      deleted: 0
    assert.deepEqual(repo.getDiffStats(modifiedFilePath), expected)

    repo.onDidChangeStatus ->
      expected =
        added: 9
        deleted: 0
      assert.deepEqual(repo.getDiffStats(modifiedFilePath), expected)
      done()

  after ->
    testRepo.destroy()
