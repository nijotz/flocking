define ['cs!canvas-tools/world', 'cs!canvas-tools/spatialsub'],
(World, SpatialSub) ->

    class Actor
        constructor: (@world) ->
            @x = world.width / 2
            @y = world.height / 2

            # Keep track of what quadrant this Actor is in.  These are set to 0 for
            # now, but will be set correctly the first time think() is called.
            @quadx = 0
            @quady = 0

            # heading is measure in radians
            this.heading = Math.random() * 2 * Math.PI
            # speed is measured in pixels per frame.
            this.speed = Math.random() * 5 + 0.5

            # targetHeading and targetSpeed are used for flocking, just set them to
            # the current heading and speed for now.
            this.targetHeading = this.heading
            this.targetSpeed = this.speed

        draw: (context)->
            context.fillStyle = "rgb(200,0,0)"
            context.beginPath()

            # Draw the butt with the arc method:
            context.arc(@x, @y, 7, @heading + Math.PI / 2, @heading - Math.PI / 2, false)

            # Draw the head with a quadradictCurve from the end point of the arc
            # method (7 units to the left of the Actor), to 7 units to the right of
            # the Actor, with a control point 30 units in front of the actor.
            context.quadraticCurveTo(this.x + Math.cos(this.heading) * 30,
                               this.y + Math.sin(this.heading) * 30,
                               this.x + Math.cos(this.heading + Math.PI / 2) * 7,
                               this.y + Math.sin(this.heading + Math.PI / 2) * 7)
            context.fill()

        # Move, calculate quad info, flock.
        update: ->
            ## Movement

            # Find the the angle from our target
            deviation = @targetHeading - @heading

            # Make sure our deviation is between -Pi and Pi instead of 0 and 2*Pi
            deviation = (deviation + Math.PI) % (Math.PI * 2) - Math.PI

            # Only go a fraction of the way to our target every frame. This smoothes
            # out the turns, making the Actors less erratic.
            @heading += deviation / 10

            # Make sure our heading is between 0 and tau
            @heading %= Math.PI * 2

            # Go a fraction of the way towards targetSpeed
            @speed += (@targetSpeed - @speed) / 10
            @speed = 1 if @speed < 1
            @speed = 6 if @speed > 6

            # Update position based on heading/speed and track old position for
            # spatialsub stuff below
            oldx = @x
            oldy = @y
            @x += Math.cos(@heading) * @speed
            @y += Math.sin(@heading) * @speed

            # If an Actor goes off screen, wrap them around to the other side
            @x = @world.width - (Math.abs(@x) % @world.width) if @x < 0
            @y = @world.height - (Math.abs(@y) % @world.height) if @y < 0
            @x %= @world.width if @x > @world.width
            @y %= @world.height if @y > @world.height

            # Space Partitioning
            # Keep track of what quadrant this actor is in. This is done to reduce the
            # the amount of calculations needed when looking for neighbors. Rather
            # than iterate over every other Actor to find out who is nearby, each
            # Actor keeps track of what quadrant they are in, and when looking for
            # nearby Actors, they can just look in their current quadrant or
            # neighboring quadrants. Once quad info is calculated, ping the
            # quadrant to increase its' activity counter and move this actor to the
            # appropriate quadrant.
            quads = @world.spatial.updateObject(this, oldx, oldy, @x, @y)
            @quadx = quads[0]
            @quady = quads[1]
            @world.pingQuadrant(@quadx, @quady)

            ## Flocking

            # Follow neighbors
            neighbors = @world.spatial.getNeighbors(this)

            # Average the headings and speeds of the neighbors and set it as the new
            # targetHeading and targetSpeed
            if neighbors.length > 0
                avgheading = 0
                avgspeed = 0
                for neighbor in neighbors
                    avgheading += neighbor.heading
                    avgspeed += neighbor.speed
                avgheading /= neighbors.length
                avgspeed /= neighbors.length
                @targetHeading = avgheading
                @targetSpeed = avgspeed

            # Randomly stray from the target a small amount to make it interesting
            @targetHeading += (Math.random() - 0.5) * Math.PI / 2
            @targetSpeed += (Math.random() - 0.5) * 2

            # Make sure our heading is between 0 and tau
            @targetHeading %= Math.PI * 2

            # Obey the speed limit
            @targetSpeed = Math.max(1, @targetSpeed % 6)

    class FlockingWorld extends World.World
        constructor: ->
            super

            @spatial = new SpatialSub(canvas)

            @activity = new Array(@spatial.numx)
            for x in [0...@spatial.numx]
                @activity[x] = new Array(@spatial.numy)
                for y in [0...@spatial.numy]
                    @activity[x][y] = 0

            @displayFPS = true

            @mousedown = false
            window.addEventListener('mousedown', @onmousedown)
            window.addEventListener('mouseup', @onmouseup)

        onmouseup: =>
            console.log('mouseup')
            @mousedown = false
        onmousedown: =>
            console.log('mousedown')
            @mousedown = true

        # Increase the activity counter for a given quadrant. Max out at 255.
        pingQuadrant: (x, y) ->
            @activity[x][y] += 20
            if @activity[x][y] > 255
                @activity[x][y] = 255

        highlightQuadrants: (context) ->
            # Highlight active quadrants based on activity.
            for x in [0...@activity.length]
                for y in [0...@activity[x].length]
                    # Only draw squares that are non-black.
                    if @activity[x][y]
                        # Fill the quadrant with a shade of blue based on activity, which is
                        # measured from 0 to 255.
                        context.fillStyle = "rgb(0,0," + @activity[x][y] + ")"
                        context.fillRect(x * @spatial.subSize, y * @spatial.subSize, @spatial.subSize, @spatial.subSize)

        update: ->
            # Every frame, reduce the activity counter of all quadrants.
            for x in [0...@activity.length]
                for y in [0...@activity[x].length]
                    @activity[x][y] -= 5
                    if @activity[x][y] < 0
                        @activity[x][y] = 0

            # Call every Actor's think method
            super

            # If the mouse is currently being held down, add an Actor to the scene.
            if @mousedown
                @objects.push(new Actor(this))

        draw: (context, interp) ->
            context.save()
            context.fillStyle = @color
            context.fillRect(0, 0, @width, @height)
            context.restore()

            @highlightQuadrants(context)

            obj.draw(context, interp) for obj in @objects

            if @displayFPS
                @drawFPS()

    module = {'FlockingWorld': FlockingWorld}
    return module
