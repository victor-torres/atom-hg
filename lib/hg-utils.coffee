fs = require 'fs'
path = require 'path'
util = require 'util'
urlParser = require 'url'
$ = require 'jquery'
{spawnSync} = require 'child_process'
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
  shortHead: null

  revision: null


  ###
  Section: Initialization and startup checks
  ###

  constructor: (repoRootPath) ->
    @rootPath = path.normalize(repoRootPath)

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

  # Parses info from `hg info` and `hgversion` command and checks if repo infos have changed
  # since last check
  #
  # Returns a {boolean} if repo infos have changed
  checkRepositoryHasChanged: () ->
    hasChanged = false
    revision = @getHgWorkingCopyRevision()
    if revision?
      if revision != @revision
        @revision = revision
        hasChanged = true

    # info = @getHgInfo()
    # if info? && info.url?
    #   if info.url != @url
    #     @url = info.url
    #     urlParts = urlParser.parse(info.url)
    #     @urlPath = urlParts.path
    #     pathParts = @urlPath.split('/')
    #     @shortHead = if pathParts.length > 0 then pathParts.pop() else ''
    #     hasChanged = true

    return hasChanged

  getShortHead: () ->
    branchFile = @rootPath + '/.hg/branch'
    if !fs.existsSync(branchFile)
      return null

    return fs.readFileSync branchFile, 'utf8'

  ###
  Section: TreeView Path Mercurial status
  ###

  # Parses `hg status`. Gets initially called by hg-repository.refreshStatus()
  #
  # Returns a {Array} array keys are paths, values are change constants. Or null
  getStatus: () ->
    statuses = @getHgStatus()
    return statuses

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
    (status & indexStatusFlags) > 0


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
    child = spawnSync('hg', params)
    if child.status != 0
      throw new Error(child.stderr.toString())
    return child.stdout.toString()

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

  # Returns on success an hg-info object. Otherwise null.
  #
  # Returns a {Object} with data from `hg info` command
  # getHgInfo: () ->
  #   try
  #     xml = @hgCommand(['info', '--xml', @rootPath])
  #     xmlDocument = $.parseXML(xml)
  #     return {
  #       url: $('info > entry > url', xmlDocument).text()
  #     }
  #   catch error
  #     @handleHgError(error)
  #     return null

  # Returns on success the current working copy revision. Otherwise null.
  #
  # Returns a {String} with the current working copy revision
  getHgWorkingCopyRevision: () ->
    try
      revisions = @hgCommand(['id', '-i', @rootPath])
      return revisions.split(':')[1]
    catch error
      @handleHgError(error)
      return null

  # Returns on success an hg-ignores array. Otherwise null.
  # Array keys are paths, values {Number} representing the status
  #
  # Returns a {Array} with path and statusnumber
  getRecursiveIgnoreStatuses: () ->
    try
      files = @hgCommand(['status', @rootPath])
    catch error
      @handleHgError(error)
      return null

    items = []
    entries = files.split('\n')
    if entries
      for entry in entries
        parts = entry.split(' ')
        status = parts[0]
        path = parts[1]
        if path? && status?
          if (status is 'I') # || status is '?')
            items.push(path.replace('..', ''))

    return items

  # Returns on success an hg-status array. Otherwise null.
  # Array keys are paths, values {Number} representing the status
  #
  # Returns a {Array} with path and statusnumber
  getHgStatus: () ->
    try
      files = @hgCommand(['status', @rootPath])
    catch error
      @handleHgError(error)
      return null

    items = []
    entries = files.split('\n')
    if entries
      for entry in entries
        parts = entry.split(' ')
        status = parts[0]
        path = parts[1]
        if path? && status?
          items.push({
            'path': path
            'status': @mapHgStatus(status)
          })

    return items

  # Returns on success a status bitmask. Otherwise null.
  #
  # * `hgPath` The path {String} for the status inquiry
  #
  # Returns a {Number} representing the status
  getHgPathStatus: (hgPath) ->
    return null unless hgPath

    try
      files = @hgCommand(['status', hgPath])
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
        path = parts[1]
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

  # This retrieves the contents of the hgpath from the `HEAD` on success.
  # Otherwise null.
  #
  # * `hgPath` The path {String}
  #
  # Returns the {String} as filecontent
  getHgCat: (hgPath) ->
    params = ['cat', hgPath]
    try
      fileContent = @hgCommand(params)
      return fileContent
    catch error
      if /no such file in rev/.test(error)
        return null

      @handleHgError(error)
      return null


# creates and returns a new {Repository} object if hg-binary could be found
# and several infos from are successfully read. Otherwise null.
#
# * `repositoryPath` The path {String} to the repository root directory
#
# Returns a new {Repository} object
openRepository = (repositoryPath) ->
  repository = new Repository(repositoryPath)
  if repository.checkBinaryAvailable()
    return repository
  else
    return null


exports.open = (repositoryPath) ->
  return openRepository(repositoryPath)
