HgRepositoryProvider = require './hg-repository-provider'

module.exports =
  activate: ->
    console.log 'Activating atom-hg...'

  deactivate: ->
    console.log 'Deactivating atom-hg...'

  getRepositoryProviderService: ->
    new HgRepositoryProvider(atom.project)
