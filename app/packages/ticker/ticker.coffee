

Ticker = class
	constructor: (@tickable) ->
		@running = no
		@timeout = 0
		@counter = new ReactiveVar 0


	reset: ->
		@tickable.reset?()
		@counter.set 0

	getCounter: ->
		@counter.get()


	setTimeout: (@timeout) ->

	play: ->
		unless @running
			@running = yes
			@run()

	stop: ->
		console.log "stop"
		@running = no

	step: ->
		@running = no
		@turn()

	turn: ->
		@tickable.turn()
		@counter.set @counter.get()+1
	run: =>
		if @running
			@turn()
			if @timeout <= 0
				Meteor.defer @run
			else
				Meteor.setTimeout @run, @timeout



