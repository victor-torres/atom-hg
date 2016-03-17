module.exports =
  activate: ->
    console.log 'Activating atom-hg...'

  getRepositoryProviderService: ->
    {
      repositoryForDirectory: (directory) ->
        console.log 'Not supported yet.'

      repositoryForDirectorySync: (directory) ->
        repositoryRoot = findRepositoryRoot(directory)
        unless repositoryRoot
          return null

        repositoryPath = repositoryRoot.getPath()
        repo = @pathToRepository[repositoryPath]
        return repo unless repo
          repo = HgRepository.open(repositoryPath, project: @project)
          return null unless repo

          # TODO: takes first repository only
          repo.setWorkingDirectory(directory.getPath())
          repo.onDidDestroy(=> delete @pathToRepository[repositoryPath])
          @pathToRepository[repositoryPath] = repo
          repo.refreshIndex()
          repo.refreshStatus()
    }

findRepositoryRoot = (directory) ->
  hgDir = directory.getSubdirectory('.hg')
  if hgDir.existsSync?()
    return directory
  else if directory.isRoot()
    return null
  else
    findRepositoryRoot(directory.getParent())
