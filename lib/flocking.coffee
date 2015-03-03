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
        think: ->
            # Movement

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

            # Update position based on heading/speed
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
            oldquadx = @quadx
            oldquady = @quady
            @quadx = parseInt(@x / @world.quadrantSize)
            @quady = parseInt(@y / @world.quadrantSize)
            @world.pingQuadrant(@quadx, @quady)
            @world.updateQuadrantObjs(this, oldquadx, oldquady, @quadx, @quady)

            # Flocking

            # Look for neighbors
            neighbors = new Array()

            maxx = @world.quadrants.length
            maxy = @world.quadrants[0].length

            # Look one quadrant in every direction from our current quadrant.
            for x in [-1..1]
                for y in [-1..1]
                    # Set the quadrant coordinates to look in.
                    lookx = @quadx + x
                    looky = @quady + y

                    # Wrap quadrant coordinates around borders.
                    lookx = maxx + lookx if lookx < 0
                    looky = maxy + looky if looky < 0
                    lookx = lookx - maxx if lookx > maxx
                    looky = looky - maxy if looky > maxy

                    # Find the first neighbor that is at this quadrant coordinate. Finding
                    # just the first neighbor isn't as accurate, but limits the amount of
                    # calculations needed when there are many Actors in play.
                    quad_neighbor = @world.quadrants[lookx][looky][1].slice(0,1)
                    neighbors = neighbors.concat(quad_neighbor)

                    # Make sure this actor doesn't put itself into the list of neighbors.
                    if x == 0 and y == 0
                        index = neighbors.indexOf(this)
                        if index >=0
                            neighbors.splice(neighbors.indexOf(this),1)

            # Follow neighbors

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

            # Randomly stray from the target a small amount
            @targetHeading += (Math.random() - 0.5) * Math.PI / 2
            @targetSpeed += (Math.random() - 0.5) * 2

            # Make sure our heading is between 0 and tau
            @targetHeading %= Math.PI * 2

            # Make sure speed is between 1 and 6
            @targetSpeed = Math.max(1, @targetSpeed % 6)

    class FlockingWorld extends World.World
        constructor: (@canvas) ->
            super
            @spatial = new SpatialSub(canvas)
            @activity = new Array(@spatial.numx)
            for x in [0...@spatial.numx]
                @activity[x] = new Array(@spatial.numy)
                for y in [0...@spatial.numy]
                    @activity[x][y] = 0
            @displayFPS = true
            @canvas.addEventListener('click', @mouseClick, false)

        mouseClick: =>
            console.log('Click')
            @objects.push(new Actor(this))

        # Increase the activity counter for a given quadrant. Max out at 255.
        pingQuadrant: (x, y) ->
            q = @quadrants[x][y]
            q[0] += 20
            if q[0] > 255
                q[0] = 255

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

        draw: ->
            # Highlight active quadrants based on activity.
            for x in [0...@activity.length]
                for y in [0...@activity[x].length]
                    # Only draw squares that are non-black.
                    if @activity[x][y]
                        # Fill the quadrant with a shade of blue based on activity, which is
                        # measured from 0 to 255.
                        c.fillStyle = "rgb(0,0," + @activity[x][y] + ")"
                        c.fillRect(x * @spatial.subSize, y * @spatial.subSize, @spatial.subSize, @spatial.subSize)

            # Call every Actor's draw method.
            super

    module = {'FlockingWorld': FlockingWorld}
    return module
