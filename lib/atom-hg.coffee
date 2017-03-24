HgRepositoryProvider = require './hg-repository-provider'

module.exports =
  config:
    diffAgainstRevision:
      type: 'string'
      description: 'Revision that Mercurial will diff against.'
      default: '.'

  activate: ->
    console.log 'Activating atom-hg...'

  deactivate: ->
    console.log 'Deactivating atom-hg...'

  getRepositoryProviderService: ->
    new HgRepositoryProvider(atom.project)
