fs = require 'fs'
path = require 'path'
util = require 'util'
urlParser = require 'url'
{spawnSync, exec} = require 'child_process'
diffLib = require 'jsdifflib'

###
Section: Constants used for file/buffer checking against changes
###
statusIndexNew = 1 << 0
statusIndexDeleted = 1 << 2

statusWorkingDirNew = 1 << 7
statusWorkingDirModified = 1 << 8
statusWorkingDirDelete = 1 << 9
statusWorkingDirTypeChange = 1 << 10
statusIgnored = 1 << 14

modifiedStatusFlags = statusWorkingDirModified | statusWorkingDirDelete |
                      statusWorkingDirTypeChange | statusIndexDeleted

newStatusFlags = statusWorkingDirNew | statusIndexNew

deletedStatusFlags = statusWorkingDirDelete | statusIndexDeleted

suppressHgWarnings = [
  'W200005' # hg: warning: W200005: 'file' is not under version control
  'E200009' # Could not cat all targets because some targets are not versioned
]

class Repository

  username: null
  password: null

  rootPath: null

  isHgRepository: false
  binaryAvailable: false

  version: null

  url: null
  urlPath: null

  revision: null
  diffRevisionProvider: null

  ###
  Section: Initialization and startup checks
  ###

  constructor: (repoRootPath, diffRevisionProvider) ->
    @rootPath = path.normalize(repoRootPath)
    unless fs.existsSync(@rootPath)
      return

    lstat = fs.lstatSync(@rootPath)
    unless lstat.isSymbolicLink()
      return

    @diffRevisionProvider = diffRevisionProvider
    @rootPath = fs.realpathSync(@rootPath)

  # Checks if there is a hg binary in the os searchpath and returns the
  # binary version string.
  #
  # Returns a {boolean}
  checkBinaryAvailable: () ->
    @version = @getHgVersion()
    if @version?
      @binaryAvailable = true
    else
      @binaryAvailable = false
    return @binaryAvailable

  exists: () ->
    return fs.existsSync(@rootPath + '/.hg')

  # Parses info from `hg info` and `hgversion` command and checks if repo infos have changed
  # since last check
  #
  # Returns a {Promise} of a {boolean} if repo infos have changed
  checkRepositoryHasChangedAsync: () =>
    return @getHgWorkingCopyRevisionAsync().then (revision) =>
      if revision? and revision != @revision
        @revision = revision
        return true
      return false

  getShortHeadAsync: () =>
    return new Promise (resolve) =>
      branchFile = @rootPath + '/.hg/branch'
      bookmarkFile = @rootPath + '/.hg/bookmarks.current'
      prompt = 'default'

      fs.readFile branchFile, 'utf8', (err, data) =>
        prompt = data.trim() unless err
        fs.readFile bookmarkFile, 'utf8', (err, data) =>
          prompt += ':' + data.trim() unless err
          @getHgTagsAsync().then (tags) ->
            prompt += ':' + tags.join(',') if tags?.length
          .then () -> # Finally
            resolve prompt



  ###
  Section: TreeView Path Mercurial status
  ###

  # Parses `hg status`. Gets initially called by hg-repository.refreshStatus()
  #
  # Returns a {Promise} of an {Array} array keys are paths, values are change
  # constants. Or null
  getStatus: () ->
    return @getHgStatusAsync()

  # Parses `hg status`. Gets called by hg-repository.refreshStatus()
  #
  # Returns an {Array} Array keys are paths, values are change constants
  getPathStatus: (hgPath) ->
    status = @getHgPathStatus(hgPath)
    return status

  getPath: () ->
    return @rootPath

  isStatusModified: (status=0) ->
    (status & modifiedStatusFlags) > 0

  isPathModified: (path) ->
    @isStatusModified(@getPathStatus(path))

  isStatusNew: (status=0) ->
    (status & newStatusFlags) > 0

  isPathNew: (path) ->
    @isStatusNew(@getPathStatus(path))

  isStatusDeleted: (status=0) ->
    (status & deletedStatusFlags) > 0

  isPathDeleted: (path) ->
    @isStatusDeleted(@getPathStatus(path))

  isPathStaged: (path) ->
    @isStatusStaged(@getPathStatus(path))

  isStatusIgnored: (status=0) ->
    (status & statusIgnored) > 0

  isStatusStaged: (status=0) ->
    (status & statusWorkingDirNew) == 0


  ###
  Section: Editor Mercurial line diffs
  ###

  # Public: Retrieves the number of lines added and removed to a path.
  #
  # This compares the working directory contents of the path to the `HEAD`
  # version.
  #
  # * `path` The {String} path to check.
  # * `lastRevFileContent` filecontent from latest hg revision.
  #
  # Returns an {Object} with the following keys:
  #   * `added` The {Number} of added lines.
  #   * `deleted` The {Number} of deleted lines.
  getDiffStats: (path, lastRevFileContent) ->
    diffStats = {
      added: 0
      deleted: 0
    }
    if (lastRevFileContent? && fs.existsSync(path))
      base = diffLib.stringAsLines(lastRevFileContent)
      newtxt = diffLib.stringAsLines(fs.readFileSync(path).toString())

      # create a SequenceMatcher instance that diffs the two sets of lines
      sm = new diffLib.SequenceMatcher(base, newtxt)

      # get the opcodes from the SequenceMatcher instance
      # opcodes is a list of 3-tuples describing what changes should be made to the base text
      # in order to yield the new text
      opcodes = sm.get_opcodes()

      for opcode in opcodes
        if opcode[0] == 'insert' || opcode[0] == 'replace'
          diffStats.added += (opcode[2] - opcode[1]) + (opcode[4] - opcode[3])
        if opcode[0] == 'delete'
          diffStats.deleted += (opcode[2] - opcode[1]) - (opcode[4] - opcode[3])

    return diffStats

  # Public: Retrieves the line diffs comparing the `HEAD` version of the given
  # path and the given text.
  #
  # * `lastRevFileContent` filecontent from latest hg revision.
  # * `text` The {String} to compare against the `HEAD` contents
  #
  # Returns an {Array} of hunk {Object}s with the following keys:
  #   * `oldStart` The line {Number} of the old hunk.
  #   * `newStart` The line {Number} of the new hunk.
  #   * `oldLines` The {Number} of lines in the old hunk.
  #   * `newLines` The {Number} of lines in the new hunk
  getLineDiffs: (lastRevFileContent, text, options) ->
    hunks = []

    if (lastRevFileContent?)
      base = diffLib.stringAsLines(lastRevFileContent)
      newtxt = diffLib.stringAsLines(text)
      # create a SequenceMatcher instance that diffs the two sets of lines
      sm = new diffLib.SequenceMatcher(base, newtxt)

      # get the opcodes from the SequenceMatcher instance
      # opcodes is a list of 3-tuples describing what changes should be made to the base text
      # in order to yield the new text
      opcodes = sm.get_opcodes()

      actions = ['replace', 'insert', 'delete']
      for opcode in opcodes
        if actions.indexOf(opcode[0]) >= 0
          hunk = {
            oldStart: opcode[1] + 1
            oldLines: opcode[2] - opcode[1]
            newStart: opcode[3] + 1
            newLines: opcode[4] - opcode[3]
          }
          if opcode[0] == 'delete'
            hunk.newStart = hunk.newStart - 1
          hunks.push(hunk)

    return hunks

  ###
  Section: Mercurial Command handling
  ###

  # Spawns an hg command and returns stdout or throws an error if process
  # exits with an exitcode unequal to zero.
  #
  # * `params` The {Array} for commandline arguments
  #
  # Returns a {String} of process stdout
  hgCommand: (params) ->
    if !params
      params = []
    if !util.isArray(params)
      params = [params]

    if !@isCommandForRepo(params)
      return ''

    child = spawnSync('hg', params, { cwd: @rootPath })
    if child.status != 0
      if child.stderr
        throw new Error(child.stderr.toString())

      if child.stdout
        throw new Error(child.stdout.toString())

      throw new Error('Error trying to execute Mercurial binary with params \'' + params + '\'')

    return child.stdout.toString()

  hgCommandAsync: (params) ->
    if !params
      params = []
    if !util.isArray(params)
      params = [params]

    if !@isCommandForRepo(params)
      return Promise.resolve('')

    flatArgs = params.reduce (prev, next) ->
      if next.indexOf? and next.indexOf(' ') != -1
        next = "\"" + next + "\""

      prev + " " + next
    , ""
    flatArgs = flatArgs.substring(1)

    return new Promise (resolve, reject) =>
      opts =
        cwd: @rootPath
        maxBuffer: 50 * 1024 * 1024
      child = exec 'hg ' + flatArgs, opts, (err, stdout, stderr) ->
        if err
          reject err
        if stderr?.length > 0
          reject stderr
        resolve stdout

  handleHgError: (error) ->
    logMessage = true
    message = error.message
    for suppressHgWarning in suppressHgWarnings
      if message.indexOf(suppressHgWarning) > 0
        logMessage = false
        break
    if logMessage
      console.error('Mercurial', 'hg-utils', error)

  # Returns on success the version from the hg binary. Otherwise null.
  #
  # Returns a {String} containing the hg-binary version
  getHgVersion: () ->
    try
      version = @hgCommand(['--version', '--quiet'])
      return version.trim()
    catch error
      @handleHgError(error)
      return null

  # Returns on success the current working copy revision. Otherwise null.
  #
  # Returns a {Promise} of a {String} with the current working copy revision
  getHgWorkingCopyRevisionAsync: () =>
    @hgCommandAsync(['id', '-i', @rootPath]).catch (error) =>
      @handleHgError(error)
      return null

  getRecursiveIgnoreStatuses: () ->
    revision = @diffRevisionProvider()
    @hgCommandAsync(['status', @rootPath, "-i", "--rev", revision])
    .then (files) =>
      items = []
      entries = files.split('\n')
      if entries
        for entry in entries
          parts = entry.split(' ')
          status = parts[0]
          pathPart = parts[1]
          if pathPart? && status?
            if (status is 'I') # || status is '?')
              items.push(pathPart.replace('..', ''))
      (path.join @rootPath, item for item in items)
    .catch (error) =>
      @handleHgError error
      []

  getHgStatusAsync: () ->
    revision = @diffRevisionProvider()
    @hgCommandAsync(['status', @rootPath, '--rev', revision]).then (files) =>
      items = []
      entries = files.split('\n')
      if entries
        for entry in entries
          parts = entry.split(' ')
          status = parts[0]
          pathPart = parts[1]
          if pathPart? && status?
            items.push({
              'path': path.join @rootPath, pathPart
              'status': @mapHgStatus(status)
            })

      return items
    .catch (error) =>
      @handleHgError(error)
      return null

  # Returns on success the list of tags for this revision. Otherwise null.
  #
  # Returns a {Primise} of an {Array} of {String}s representing the status
  getHgTagsAsync: () ->
    @hgCommandAsync(['id', '-t', @rootPath]).then (tags) ->
      tags = tags.trim()
      return tags.split(' ').sort() if tags
    .catch (error) =>
      @handleHgError(error)
      return null

  # Returns on success a status bitmask. Otherwise null.
  #
  # * `hgPath` The path {String} for the status inquiry
  #
  # Returns a {Number} representing the status
  getHgPathStatus: (hgPath) ->
    return null unless hgPath

    try
      revision = @diffRevisionProvider()
      files = @hgCommand(['status', hgPath, '--rev', revision])
    catch error
      @handleHgError(error)
      return null

    items = []
    entries = files.split('\n')
    if entries
      path_status = 0
      for entry in entries
        parts = entry.split(' ')
        status = parts[0]
        pathPart = parts[1]
        if status?
          path_status |= @mapHgStatus(status)
      return path_status
    else
      return null

  # Translates the status {String} from `hg status` command into a
  # status {Number}.
  #
  # * `status` The status {String} from `hg status` command
  #
  # Returns a {Number} representing the status
  mapHgStatus: (status) ->
    return 0 unless status
    statusBitmask = 0

    # status workingdir
    if status == 'M'
      statusBitmask = statusWorkingDirModified
    if status == '?'
      statusBitmask = statusWorkingDirNew
    if status == '!'
      statusBitmask = statusWorkingDirDelete
    if status == 'I'
      statusBitmask = statusIgnored
    if status == 'M'
      statusBitmask = statusWorkingDirTypeChange

    # status index
    if status == 'A'
      statusBitmask = statusIndexNew
    if status == 'R'
      statusBitmask = statusIndexDeleted

    return statusBitmask

  # This retrieves the contents of the hgpath from the diff revision on success.
  # Otherwise null.
  #
  # * `hgPath` The path {String}
  #
  # Returns {Promise} of a {String} with the filecontent
  getHgCatAsync: (hgPath) ->
    revision = @diffRevisionProvider()
    params = ['cat', hgPath, '--rev', revision]
    return @hgCommandAsync(params).catch (error) =>
      if /no such file in rev/.test(error)
        return null

      @handleHgError error
      return null

  # This checks to see if the current params indicate whether we are working
  # with the current repository.
  #
  # * `params` The params that are going to be sent to the hg command {Array}
  #
  # Returns a {Boolean} indicating if the rootPath was found in the params
  isCommandForRepo: (params) ->
    rootPath = @rootPath

    paths = params.filter (param) ->
      normalizedPath = path.normalize((param || ''))
      return normalizedPath.startsWith(rootPath)

    return paths.length > 0


exports.isStatusModified = (status) ->
  return (status & modifiedStatusFlags) > 0

exports.isStatusNew = (status) ->
  return (status & newStatusFlags) > 0

exports.isStatusDeleted = (status) ->
  return (status & deletedStatusFlags) > 0

exports.isStatusIgnored = (status) ->
  return (status & statusIgnored) > 0

exports.isStatusStaged = (status) ->
  return (status & statusWorkingDirNew) == 0


# creates and returns a new {Repository} object if hg-binary could be found
# and several infos from are successfully read. Otherwise null.
#
# * `repositoryPath` The path {String} to the repository root directory
#
# Returns a new {Repository} object
openRepository = (repositoryPath, diffRevisionProvider) ->
  repository = new Repository(repositoryPath)
  if repository.checkBinaryAvailable() and repository.exists()
    repository.diffRevisionProvider = diffRevisionProvider
    return repository
  else
    return null


exports.open = (repositoryPath, diffRevisionProvider) ->
  return openRepository(repositoryPath, diffRevisionProvider)

# Verifies if given path is a symbolic link.
# Returns original path or null otherwise.
resolveSymlink = (repositoryPath) ->
  lstat = fs.lstatSync(repositoryPath)
  unless lstat.isSymbolicLink()
    return null

  return fs.realpathSync(repositoryPath)

exports.resolveSymlink = (repositoryPath) ->
  return resolveSymlink(repositoryPath)
