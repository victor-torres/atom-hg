require 'coffee-script/register'
require './fakeWindow'
HgRepository = require '../lib/hg-repository'
TestRepository = require './testRepository'
assert = require('chai').assert

describe 'In a repo without any tags or bookmarks', ->
  testRepo = new TestRepository 'tagless_repo'

  before ->
    testRepo.init()

  it 'should show "default" as the short-head', (done) ->
    repo = new HgRepository testRepo.fullPath()
    repo.onDidChangeStatuses ->
      assert.equal(repo.shortHead, 'default')
      done()
    repo.getShortHead(testRepo.fullPath())

  after ->
    testRepo.destroy()
