_ = require 'lodash'
request = require 'request'
Worksheet = require './worksheet'


module.exports = class Document

	defaults =
		wanted: []
		simpleSheet: false
		parseNumbers: false
		wait: false
		reverse: false
		postProcess: ->
		debug: false
		query: ''
		orderBy: undefined
		endpoint: 'https://spreadsheets.google.com'
		singleton: undefined
		simple_url: false
		callbackContext: undefined
		prettyColumnNames: false
		authKey: undefined
		proxy: undefined
		parameterize: false
		supportsCORS: true

	###*
	 * Class level callbacks queue
	 * @type {Object}
	###
	@callbacks = {}

	urlTemplates:
		Document: 'feeds/spreadsheets/'
		Sheet: '/feeds/worksheets/${document_id}'
		Cells: '/feeds/list/${document_id}/${sheet_id}'

	init: (options)-> new Tabletop(options)

	constructor: (options)->
		# if it's a string, then it's the sheet key
		if typeof options is 'string'
			options = key: options

		@options = _.defaults options, defaults
		@models = {}
		@modelNames = []

		if @options.proxy?
			@options.endpoint = @options.proxy.replace /\/$/, ''
			@options.simple_url = true
			@options.singleton = true
			@options.supportsCORS = false

		if @options.singleton
			if typeof(@constructor.singleton)?
				@log 'singleton already defined'
			@constructor.singleton = @

		@baseJsonPath = @buildUrl 'Worksheet', @options

		if not @wait
			@fetch()

	###*
	 * Fetch document
	 * @return {JSON} [description]
	###
	sheets: ->
		url = @buildUrl 'Document'
		@requestData url, this.loadSheets

	###*
	 * Add oauth2 access token
	 * @param {String} @accessToken valid oauth2 token
	###
	setAccessToken: (@accessToken)->

	fetch: (done)->
		@callback = done if done?
		@requestData @baseJsonPath, @loadSheets

	requestData: (path, done)->
		@serverSideFetch path, done

	# xhrFetch: (path, done)->

	###*
	 * [serverSideFetch description]
	 * @param  {[type]}   path [description]
	 * @param  {Function} done [description]
	 * @original tabletop.js:#245
	 * @return {[type]}        [description]
	###
	serverSideFetch: (path, done)->
		options =
			url: @endpoint + path
			json: true

		request options, (err, response, body)=>
				return @log err unless not err
				done.call(@, body)

	###*
	 * Test if the sheet has been whitelisted
	 * @param  {String}  sheetname name of the worksheet
	 * @original tabletop.js:#262
	 * @return {Boolean}           indication
	###
	isWanted: (sheetname)->
		return true if @wanted.length is 0
		return sheetname in @wanted

	addWanted: (sheetname)->
		if not sheetname in @wanted
			@wanted.push sheetname

	###*
	 * Post process the data returned from the server
	 * @return {[type]} [description]
	 * @chain RemoteDataFetch: PostProcess
	 * @original tabletop.js:#274
	 * @todo: rename this to onPostProcessData
	###
	data: ->
		return undefined if @model_names.length <= 0

		return @models if not @options.simpleSheet

		if @model_names.length > 1 and @options.debug
			@log "<warning>, you have more than one sheet and are trying to use SimpleSheets."

		return @models[@model_names[0]].all()

	###*
	 * any url used in tabletop is created from here to maintain
	 * consistency
	 * @param  {String} type   one of : Document, Sheet, Cells
	 * @param  {Object} kwargs list of url arg parameters
	 * @return {String}        url
	###
	buildUrl: (type, kwargs)->
		if not type in Object.keys(@urlTemplates)
			throw Error "Invalid urltemplate type", type

		template = [@urlTemplates[type]]

		if 'access_token' of kwargs
			template.push '/private/full'
		else
			template.push '/public/full'

		template.push '?alt=json'

		if 'query' of kwargs
			template.push '&sq=${query}'

		if 'orderby' of kwargs
			template.push '&orderby=column:${orderby.toLowerCase()}'

		if 'reverse' of kwargs
			template.push '&reverse=true'

		if 'access_token' of kwargs
			template.push '&access_token=${access_token}'

		return _.template(template.join(''))(kwargs)

	###*
	 * Load all sheets described in the current document
	 * @param  {Object} data JSON object returned from initial document fetch
	 * @return {Null}
	###
	loadSheets: (data)->
		sheetnames = []
		queue = []

		for sheet in data.feed.entry
			sheetnames.push sheet.title.$t
			if @isWanted sheet.content.$t

				url = @buildUrl 'Sheet',
					document_id: @options.key
					sheet_id: sheet.id.$t.split('/').pop()
					query: @options.query
					orderby: @options.orderby
					reverse: @options.reverse
					access_token: @options.access_token

				queue.push url

		@sheetsToLoad = queue.length

		for url in queue
			@requestData url, @loadSheet

	sheets: (sheetname)->
		if not sheetname?
			@models
		else if  @models[sheetname]?
			return
		else
			return @models[sheetname]

	sheetReady: (model)->
		@models[model.name] = model
		if not model.name in @model_names
			@model_names.push model.name
		@sheetsToLoad -= 1
		@done() if @sheetsToLoad <= 0

	loadSheet: (data)->
		model = new Worksheet
			data: data
			parseNumbers: @options.parseNumbers
			postProcess: @options.postProcess
			tabletop: @
			prettyColumnNames: @options.prettyColumnNames
			onReady: => @sheetReady(model)

	log: ->
			# bail if debug not enabled
			return unless not @debug
			# bail if there is no console object
			return unless console? and console.log?()

			Function::apply.apply(console.log, [console, arguments])
