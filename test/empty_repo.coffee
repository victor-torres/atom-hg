require 'coffee-script/register'
require './fakeWindow'
HgRepository = require '../lib/hg-repository'
TestRepository = require './testRepository'
assert = require('chai').assert

testRepo = new TestRepository 'empty_repo'
before ->
  testRepo.init()

describe 'Constructing hg-repository', ->
  it 'should throw exception on nonexisting repository', ->
    assert.throws ->
      repo = new HgRepository (testRepo.fullPath() + "_not_exists")
    , 'No Mercurial repository found searching path: ' + testRepo.fullPath()

  it 'should create a repo from an empty repository', ->
    repo = new HgRepository testRepo.fullPath()
    assert.ok repo

after ->
  testRepo.destroy()
