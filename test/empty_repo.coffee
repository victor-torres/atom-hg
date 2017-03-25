require 'coffee-script/register'
require './fakeWindow'
HgRepository = require '../lib/hg-repository'
TestRepository = require './testRepository'
assert = require('chai').assert

describe 'Constructing hg-repository', ->
  testRepo = new TestRepository 'empty_repo'

  before ->
    testRepo.init()

  it 'should throw exception on nonexisting repository', ->
    assert.throws ->
      repo = new HgRepository (testRepo.fullPath() + "_not_exists")
    , 'No Mercurial repository found searching path: ' + testRepo.fullPath()

  it 'should create a repo from an empty repository', ->
    repo = new HgRepository testRepo.fullPath()
    assert.ok repo

  it 'should show "default:tip" as the short-head', (done) ->
    repo = new HgRepository testRepo.fullPath()
    repo.onDidChangeStatuses ->
      assert.equal(repo.shortHead, 'default:tip')
      done()
    repo.getShortHead(testRepo.fullPath())

  after ->
    testRepo.destroy()
