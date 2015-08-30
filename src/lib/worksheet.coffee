_ = require 'lodash'

module.exports = class Worksheet

	defaults = {}

	constructor: (options)->
		throw new Error('Options must be an object') unless typeof(options) is 'Object'
		@options = _.defaults options, defaults

		throw new Error('Missing TableTop reference') unless options.tabletop
		@tabletop = options.tabletop

		throw new Error('Missing data') unless options.data?.feed?
		@name = options.data.feed.title.$t
		@elements = []
		@column_names = []
		@raw = options.data

		if options.data.feed.entry?
			@tabletop.log "Missing data for #{@name}, make sure you didn't forget column headers"
			@original_columns = []
			@elements = []
			@onReady.call(@)
			return

		@buildColumnNames()
		@buildEntries()

		buildColumnNames: ->
			for key in @raw.feed.entry[0]
				if /^gsx/.test(key)
					@column_names.push key.replace 'gsx$', ''
			@original_columns = @column_names

		buildEntries: ->
			for entry, index in @raw.feed.entry
				@elements.push @processRow(entry, index)
			if @options.prettyColumnNames
				@fetchPrettyColumns()
			else
				@onReady.call @

		processRow: (row, index)->
			output = {}
			for column_name in @column_names
				cell = row["gsx$#{column_name}"]
				output[column_name] = @processCell cell

			if ouput.rowNumber?
				output.rowNumber += index + 1

			if @options.postProcess
				@options.postProcess(output)

		processCell: (cell)->
			if cell?
				if @options.parseNumbers and not cell.$t is '' and not isNan(cell.$t)
					 return +cell.$t
				else
					return cell.$st
			else
				return ''

		all: ->
			return @elements

		pullWorkSheetId: (url)->
			pattern = /https\:\/\/spreadsheets\.google\.com\/feeds\/cells\/.*\/(.*)\/private\/full\/batch/
			return pattern.match(url)

		fetchPrettyColumns: ->
			return @ready() unless this.raw.feed.link[3]
			original_url = @raw.feed.link[3].href
			original_url.match
				.replace '/feeds/list/', '/feeds/cells/'
				.replace 'https://spreadsheets.google.com', ''

			if (@tabletop.accessToken)
				cellurl += "&access_token=#{@tabletop.authkey}"

			@tabletop.requestData cellurl, (data)=>
				@loadPrettyColumns data

		ready: ->
			this
		loadPrettyColumns: ->

		prettifyElements: ->

		toArray: ->
