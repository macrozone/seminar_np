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

		if @yield() + item.value <= @size
			@items.push item
			@dep.changed()
		else
			console.log "item does not fit"
	yield: -> 
		_.reduce @getItems(), ((total, item) -> total+item.value), 0
	getItems: ->
		@dep.depend()
		@items

	





if Meteor.isClient
	greedy = (item) -> if item? then yes else no

	Algorithm = class
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
				name: -> "Greedy G"
				description: -> "G archieves at least 1-beta, where beta is here #{@beta}"
				beta: 0.8
				Algorithm: class extends Algorithm
					decide: greedy

					
			,
				name: "AONE - with one advice bit"
				description: "AONE is 2-competitive"
				beta: 0.55
				Algorithm: class extends Algorithm
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


	createItems = ({beta, maxSize}) ->
		items = []
		beta ?= 0.5
		maxSize ?= 1
		totalSize = 0
		index = 0
		until totalSize >= maxSize
			
			value = Math.random()*beta
			totalSize += value
			items.push {index, value}
			index++
		return items.reverse() # we later pop the elements out (from the end) because it is faster

	Template.Experiment.onCreated ->
		
		@items = []
		@knapsack = new Knapsack 
		@currentItem = new ReactiveVar
		@algorithm = new @data.Algorithm
		@yieldHistory = 
			history: []
			dep: new Tracker.Dependency
			add: (yieldValue) ->
				@worstYield = Math.min @worstYield ? yieldValue, yieldValue
				@bestYield = Math.max @bestYield ? yieldValue, yieldValue
				@history.push yieldValue
				@dep.changed()
			size: ->
				@dep.depend()
				@history.length
			worst: ->
				@dep.depend()
				@worstYield
			best: ->
				@dep.depend()
				@bestYield
			avg: ->
				@dep.depend()
				if @history.length > 0
					(_.reduce @history, (total, value) -> total+value)/@history.length
			reset: ->
				@history = []
				@bestYield = null
				@worstYield = null
				@dep.changed()
		resetExperiment = =>
			@knapsack.reset()
			@items = createItems beta: @data.beta
			@currentItem.set @items.pop()
			@algorithm.reset?()
			@algorithm.askOracle? @items
		do reset = =>
			@yieldHistory.reset()
			resetExperiment()
		
		@ticker = new Ticker 
			reset: =>
				reset()

			turn: =>
				# 1. step: fetch new item
				# 2. step: put it in knapsack
				
				item = @currentItem.get()
				if item?
					if @algorithm.decide item
						@knapsack.addItem item
					@currentItem.set @items.pop()
				else
					# no more items
					
					@yieldHistory.add @knapsack.yield()
					resetExperiment()
					

	
	Template.Experiment.helpers 
		adviceBits: -> Template.instance().algorithm.adviceBits.get()
		act: -> Template.instance().algorithm.act.get()
		knapsack: -> Template.instance().knapsack
		ticker: -> Template.instance().ticker
		currentItem: ->Template.instance().currentItem?.get()
		yieldHistory: -> Template.instance().yieldHistory
	
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
		'click .btn-play': -> 
			@ticker.setTimeout 100
			@ticker.play()
		'click .btn-play-fast': ->
			@ticker.setTimeout 0
			@ticker.play()

		'click .btn-stop': -> @ticker.stop()
		'click .btn-reset': -> @ticker.reset()

	


