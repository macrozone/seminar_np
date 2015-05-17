Constants = 
	SCALE: 300
createNormalDistributedRandomNumber = ->
	((Math.random() + Math.random() + Math.random() + Math.random() + Math.random() + Math.random()) - 3) / 3



Knapsack = class 
	constructor: ->
		@dep = new Tracker.Dependency
		@reset()

	reset: ->
		@size = 1
		@scale = 300
		@items = []
		@dep.changed()
		

		

	addItem: (item) ->

		if @totalValue() + item.value <= @size
			@items.push item
			@dep.changed()
		else
			console.log "item does not fit"
	totalValue: -> 
		_.reduce @getItems(), ((total, item) -> total+item.value), 0
	getItems: ->
		@dep.depend()
		@items

	





if Meteor.isClient
	greedy = (item) -> if item? then yes else no

	Experiment = class
		constructor: ->
			@adviceBits = new ReactiveVar
			@act = new ReactiveVar
		askOracle: (items) ->
			if @oracle?
				@adviceBits.set @oracle items
		readAdviceBit: (index) ->
			@adviceBits.get()?[index]
		reset: ->
			@adviceBits.set null
			@act.set null


	Template.experiments.helpers
		experiments: ->
			[
				name: "Greedy G"
				description: "G archieves at least 1-beta, where beta is here 0.5"
				Experiment: class extends Experiment
					decide: greedy
					
			,
				name: "AONE - with one advice bit"
				description: "AONE is 2-competitive"
				Experiment: class extends Experiment
					oracle: (items) ->
						[_.some items, (item) -> item.value > 0.5]
					decide: (item)-> 
						adviceBit = @readAdviceBit item.index
						if adviceBit? 
							if adviceBit is off then @act.set "greedy" else @act.set "wait"
						if @act.get() is "greedy" then greedy item else @wait item
						
					wait: (item) ->
						if item?.value > 0.5
							@act.set "greedy"
							greedy item
						else
							no
					



			]


	createItems = (number = 10, totalSize = 1, maxSize=0.6) ->
		items = []
		for index in [number..0]
			value = Math.random()*maxSize
			items.push {index, value}
		return items

	Template.Experiment.onCreated ->
		
		@items = []
		@knapsack = new Knapsack 
		@currentItem = new ReactiveVar
		@experiment = new @data.Experiment

		setup = =>
			@currentItem.set null
			@knapsack.reset()
			@items = createItems()
			@experiment.reset?()
			@experiment.askOracle? @items
		setup()
		@ticker = new Ticker 
			reset: =>
				
				setup()

			turn: =>
				# 1. step: fetch new item
				# 2. step: put it in knapsack
				newItem = @items.pop()
				lastItem = @currentItem.get()
				@currentItem.set newItem
				if lastItem? and @experiment.decide lastItem
					@knapsack.addItem lastItem
		@ticker.setTimeout 500

	
	Template.Experiment.helpers 
		adviceBits: -> Template.instance().experiment.adviceBits.get()
		act: -> Template.instance().experiment.act.get()
		knapsack: -> Template.instance().knapsack
		ticker: -> Template.instance().ticker
		currentItem: ->Template.instance().currentItem?.get()
	
			
	Template.Knapsack.helpers
		totalWidth: ->
			@size * Constants.SCALE+1 #1 is for rounding issues
		items: -> 
			@getItems()
	Template.KnapsackItem.helpers
		width:  -> 
			@value * Constants.SCALE
		color: ->
			hue = @value*360
			"hsl(#{hue}, 73%, 69%)"

	Template.TickerGui.helpers
		counter: -> @ticker.getCounter()
	Template.TickerGui.events
		'click .btn-step': -> @ticker.step()
		'click .btn-play': -> @ticker.play()
		'click .btn-stop': -> @ticker.stop()
		'click .btn-reset': -> @ticker.reset()

	


