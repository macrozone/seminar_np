	Constants = 
		SCALE: 300
		KNAPSACK_SIZE: 1

	roundValue = (value) -> Math.round(value*100)/100

## Knapsack 

The Knapsack will contain the objects and can return its yield (= the total of items' value)


	Knapsack = class 
		constructor: ->
			@size = Constants.KNAPSACK_SIZE
			@dep = new Tracker.Dependency
			@reset()

		reset: ->
			@items = []
			@dep.changed()
			
		addItem: (item) ->
			if @yield() + item.value <= Constants.KNAPSACK_SIZE
				@items.push item
				@dep.changed()
		yield: -> 
			roundValue _.reduce @getItems(), ((total, item) -> total+item.value), 0
		getItems: ->
			@dep.depend()
			@items

	


	if Meteor.isClient
		experiments = []

		Algorithm = class
			constructor: ->
				@adviceBits = new ReactiveVar
				@act = new ReactiveVar
			askOracle: (items) ->
				if @oracle?
					@adviceBits.set @oracle items
					delete item.isPartOfSolution for item in items
			readAdviceBit: (index) ->
				@adviceBits.get()?[index]
			reset: ->
				@adviceBits.set null
				@act.set null
			doAct: (like) -> @act.set like
			acts: (like) -> @act.get() is like


Lets start with the greedy aproach. Here, we just take every item we get:

		decideGreedy = (item) -> yes

and we define an algorithm with it:

		Greedy = class extends Algorithm
			decide: decideGreedy

The yield of this algorithm is at least 1-b, where beta is the size of the item with the highest value (weight).
Lets do some experiments with it:

		experiments.push
			name: -> "Greedy G"
			description: -> "G archieves at least 1-beta, where beta is here #{@beta}"
			beta: 0.5
			Algorithm: Greedy
		
		experiments.push
			name: -> "Greedy G"
			description: -> "G archieves at least 1-beta, where beta is here #{@beta}"
			beta: 0.2
			Algorithm: Greedy

		experiments.push
			name: -> "Greedy G"
			description: -> "G archieves at least 1-beta, where beta is here #{@beta}"
			beta: 0.8
			Algorithm: Greedy

## Advice bits

Imaging you had an oracle, that would know all items that will come. 
How many bits of information from this oracle would you need to get an optimal solution? 
And for a given amount of these advice bits, how good would your algorithm perform?

Let's start with the first question.

Consider an algorithm with an oracle, that would give us a bit for every item coming with 

 - value 1 if the item is part of the solution
 - value 0 if the item does not belong to the solution

We now define an algorithm for that.

Note: The items are prepared in a way, that some are allready marked as solution. That makes it easier
to define the oracle here:

		TotalInformation = class extends Algorithm
			oracle: (items) ->
				bits = []
				for item in items
					bits[item.index] = if item.isPartOfSolution then 1 else 0
				# we do not need the last (n-1)
				bits.pop()
				return bits

The decision is now easy. If we have a bit (yes / no), we use it:

			decide: (item) ->
				adviceBit = @readAdviceBit item.index
				if adviceBit? then adviceBit else yes

Lets do an experiment with it:				
			
		experiments.push
			name: -> "Total Information"
			beta: 0.4
			Algorithm: TotalInformation

## 1 Advice bit

What's the best yield if we had only 1 advice bit?

Let's do an experiment where we have an oracle that gives us one bit:

		AONE = class extends Algorithm
			oracle: (allItems) -> [ _.some allItems, (item) -> item.value > 0.5 ] # array with one bit

The bit tells us:

- 1: There exists an item with a size > 0.5
- 0: There is no such item

If the bit is 0, the algorithm acts greedy (like before).
If the bit is 1, the algorithm waits until the item with size > 0.5 appears and will start acting greedyly:

			decide: (item)-> 
				adviceBit = @readAdviceBit item.index
				if adviceBit? # existance
					if adviceBit is false then @doAct "greedy" else @doAct "wait"
				if @acts "greedy" then decideGreedy item else @wait item
				
			wait: (item) ->
				if item?.value > 0.5
					@doAct "greedy"
					decideGreedy item
				else
					no

We do an experiment with a max size of one item of 0.55:

		experiments.push
			name: "AONE - with one advice bit"
			description: "AONE is 2-competitive"
			beta: 0.55
			Algorithm: AONE



## Random Online-Algorithm:


		RONE = class extends AONE
			oracle: ->
				[Math.random() < 0.5]

		experiments.push
			name: "RONE - one random bit"
			description: "Is 4-competitive in expection"
			beta: 0.55
			Algorithm: RONE

	
		createItems = ({beta, maxSize}) ->
			
			items = []
			beta ?= 0.5
			maxSize ?= 1
			totalSize = 0
			
			loop 
				value =roundValue Math.random()*beta
				if totalSize+value < maxSize
					totalSize += value
					items.push {value, isPartOfSolution: yes}
				else
					# add one that fits exactly
					items.push 
						value: roundValue maxSize - totalSize
						isPartOfSolution: yes
					# add the one that does not fit
					items.push {value}
					break


			items = _.shuffle items
			for item, index in items
				item.index = index
			return items.reverse() # we later pop the elements out (from the end) because it is faster


		Template.experiments.helpers
			experiments: -> experiments


		
		Template.Experiment.onCreated ->
			
			@items = []
			@knapsack = new Knapsack 
			@currentItem = new ReactiveVar
			@numberOfItems = new ReactiveVar
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
				@algorithm.reset?()
				@algorithm.askOracle? @items
				@numberOfItems.set @items.length
				@currentItem.set @items.pop()

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
			numberOfItems: -> Template.instance().numberOfItems.get()
			willMatch: -> 
				ctx = Template.instance()
				ctx.currentItem?.get()?.value + ctx.knapsack?.yield() <= ctx.knapsack?.size
		
		Template.Knapsack.helpers
			totalWidth: ->
				@size * Constants.SCALE+2 #2 is for rounding issues
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

		


