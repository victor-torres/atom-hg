HgRepository = require './hg-repository'

findRepositoryRoot = (directory) ->
  hgDir = directory.getSubdirectory('.hg')
  if hgDir.existsSync?()
    return directory
  else if directory.isRoot()
    return null
  else
    findRepositoryRoot(directory.getParent())

module.exports =
  class HgRepositoryProvider
    constructor: (@project) ->
      @pathToRepository = {}

    repositoryForDirectory: (directory) ->
      Promise.resolve(@repositoryForDirectorySync(directory))

    repositoryForDirectorySync: (directory) ->
      repositoryRoot = findRepositoryRoot(directory)
      unless repositoryRoot
        return null

      repositoryPath = repositoryRoot.getPath()
      if !@pathToRepository
        @pathToRepository = {}

      repo = @pathToRepository[repositoryPath]
      unless repo
        repo = HgRepository.open repositoryPath,
          project: @project
          diffRevisionProvider: ->
            atom.config.get('atom-hg.diffAgainstRevision')

        return null unless repo

        # TODO: takes first repository only
        repo.setWorkingDirectory(directory.getPath())
        repo.onDidDestroy(=> delete @pathToRepository[repositoryPath])
        @pathToRepository[repositoryPath] = repo
        repo.refreshIndex()
        repo.refreshStatus()

      return repo
