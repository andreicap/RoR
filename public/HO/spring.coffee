$ ->

  # Bind links and events to handlers
  $(".play_btn").click ->
    playSimulation()
    $(this).toggle()
    $(".pause_btn").toggle()

  $(".pause_btn").click ->
    pauseSimulation()
    $(this).toggle()
    $(".play_btn").toggle()

  $(".reset_btn").click -> resetSimulation()

  $(window).on "resize", -> onResize()

  $("[data-slider]").on "change", ->
    param_name = $(this).attr("id").match(/(.+?)-slider/)[1]
    data = sliderScales[param_name]($(this).attr("data-slider"))
    $("##{param_name}-feedback").html data.toFixed(2)

  # Initialize data
  isRunning = false
  process = null
  subdivs = 100

  startupParams =
    mass:       1
    elasticity: 1
    damping:    0.1
    amplitude:  0
    pulsation:  0
    phase:      0
    position:   1
    velocity:   0
    delta:      0.5  

  spring = new Spring startupParams  

  graphs = [
    new Graph "graph2", [-1.7, 1.7], subdivs, 4.5 # F(t)
    new Graph "graph1", [-3, 3], subdivs, 3 # x, v    
  ]

  positionPath = new Path "blue"  
  velocityPath = new Path "red"  
  extForcePath = new Path "blue"

  positionPath.fill(subdivs, spring.position)
  velocityPath.fill(subdivs, spring.velocity)
  extForcePath.fill(subdivs, spring.extForce(0))

  graphs[1].attachPath positionPath
  graphs[1].attachPath velocityPath
  graphs[0].attachPath extForcePath

  anim = new SpringAnimation "spring"
  anim.update(spring.position)


  # Configure sliders and buttons
  $(".pause_btn").hide()

  linScale = (from, to) ->
    d3.scale.linear().domain([0, 100]).range([from, to])

  sliderScales =
    mass:       linScale(0.1, 3.1)
    elasticity: linScale(0, 2)
    damping:    linScale(0, 2)
    amplitude:  linScale(-1.5, 1.5)
    pulsation:  linScale(0, 4)
    phase:      linScale(-Math.PI, Math.PI)
    position:   linScale(-2, 2)
    velocity:   linScale(0, 2)
    delta:      linScale(0.2, 2)  

  $.each startupParams, (key, value) ->
    $("##{key}-slider").foundation "slider", "set_value", sliderScales[key].invert(value)


  # Handlers
  playSimulation = () ->
    console.log "Simulation started"
    process = setInterval((() -> simulate()), 100) unless isRunning
    isRunning = true

  pauseSimulation = () ->
    clearInterval process
    isRunning = false
    console.log "Simulation ended"

  resetSimulation = () ->
    params = {}
    $("[data-slider]").each (i, element) ->
      slider = $(element)
      param_name = slider.attr("id").match(/(.+?)-slider/)[1]
      params[param_name] = sliderScales[param_name](slider.attr("data-slider"))

    spring.reset params

    positionPath.fill(subdivs, spring.position)
    velocityPath.fill(subdivs, spring.velocity)
    extForcePath.fill(subdivs, spring.extForce(0))

    for g in graphs
      g.updateState()
    anim.update(spring.position)

  simulate = () ->
    [x, v, f] = spring.next()

    positionPath.data.push(x)
    velocityPath.data.push(v)
    extForcePath.data.push(f)

    for g in graphs
      g.updateState()
      g.translate()
    
    positionPath.data.shift()
    velocityPath.data.shift()
    extForcePath.data.shift()

    anim.update(x)

  onResize = () ->
    anim.resize()
    for graph in graphs
      graph.resize()


class Graph
  constructor: (graphID, range, subdivisions, aspect) ->

    @graphID = graphID

    @paths = []

    margin = {top: 10, right: 20, bottom: 10, left: 50}

    @aspectRatio = aspect

    w = $("##{@graphID}").width()
    console.log  w

    width = w - margin.left - margin.right
    height = w/@aspectRatio - margin.top - margin.bottom

    @svg = d3.select("##{@graphID}").append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .attr("viewBox", "0 0 "+ (width + margin.left + margin.right) + " " + (height + margin.top + margin.bottom))
      .attr("preserveAspectRatio", "xMinYMin")
      .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

    # clipping rect
    @svg.append("defs").append("clipPath")
      .attr("id", "clip")
      .append("rect")
      .attr("width", width)
      .attr("height", height)

    # border
    #@svg.append("rect")
    #  .attr("width", width)
    #  .attr("height", height)
    #  .attr("fill", "none")
    #  .attr("stroke", "black")
    #  .attr("stroke-width", 0.5)

    @xScale = d3.scale.linear()
      .domain([0, subdivisions-1])
      .range([0, width])

    @yScale = d3.scale.linear()
      .domain(range)
      .range([height, 0])

    @lineGenerator = d3.svg.line()
      .x( (d,i) => @xScale(i) )
      .y( (d,i) => @yScale(d) )
      .interpolate("basis")

    # x axis
    @svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + @yScale(0) + ")")
      .call(d3.svg.axis().scale(@xScale).orient("bottom").ticks(0))

    # y axis
    @svg.append("g")
      .attr("class", "y axis")
      .call(d3.svg.axis().scale(@yScale).orient("left"))

  attachPath: (p) ->
    @paths.push(p)
    @svg.append(() -> p.htmlNode.node())

  updateState: () ->
    for p in @paths
      p.interpretData(@lineGenerator)

  translate: () ->
    for p in @paths
      p.pathElement.attr("transform", null)
        .transition()
        .duration(50)
        .ease("linear")
        .attr("transform", "translate(" + @xScale(-1) + ",0)")

  resize: () ->
    width = $("##{@graphID}").width()
    d3.select("##{@graphID} svg")
      .attr("width", width)
      .attr("height", width/@aspectRatio)



class Path
  constructor: (color) ->

    @data = []    
    xmlns = "http://www.w3.org/2000/svg"
    @htmlNode = d3.select(document.createElementNS(xmlns, "g"))
      .attr("clip-path", "url(#clip)")
      
    @pathElement = @htmlNode.append("svg:path")
      .attr("stroke", color)
      .attr("stroke-width", 2)
      .attr("fill", "none")

  fill: (n, d) ->
    @data.length = 0
    while @data.length < n
      @data.push(d)

  interpretData: (generator) ->
    @pathElement.attr("d", generator(@data))



class Spring
  constructor: (params) ->
    @reset(params)

  reset: (params) ->
    @t = 0.0
    $.each params, (k, v) => @[k] = v

    @extForce = (t) => @amplitude * Math.sin(@pulsation * t + @phase)

  next: ->
    f1 = (t, ys) => ys[1]
    f2 = (t, ys) =>
      (@extForce(t) - @damping * ys[1] - @elasticity * ys[0]) / @mass

    [@position, @velocity] = rk4([f1, f2], @delta, @t, [@position, @velocity])
    f = @extForce(@t)
    @t += @delta
    [@position, @velocity, f]


rk4 = (fs, h, t, ys) ->
  vectorSum = (v1, v2) ->
    (v1[i] + v2[i]) for v, i in v1
  scalarMul = (v, a) -> v.map((x) -> x * a)

  h2 = 0.5 * h
  k1 = fs.map( (f) -> f(t, ys) )
  k2 = fs.map( (f) -> f(t + h2, vectorSum(ys, scalarMul(k1,h2))) )
  k3 = fs.map( (f) -> f(t + h2, vectorSum(ys, scalarMul(k2,h2))) )
  k4 = fs.map( (f) -> f(t + h, vectorSum(ys, scalarMul(k3,h))) )
  u = scalarMul(k2, 2)
  v = scalarMul(k3, 2)
  w = vectorSum(vectorSum(vectorSum(k1, u), v), k4)  # inefficient but should work
  vectorSum(ys, scalarMul(w, (1 / 6.0) * h))



class SpringAnimation
  constructor: (graphID) ->
    margin = {top: 0, right: 0, bottom: 20, left: 0}

    width = $("##{graphID}").width() - margin.left - margin.right
    height = width

    @graphID = graphID

    @svg = d3.select("##{graphID}").append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .attr("viewBox", "0 0 "+ (width + margin.left + margin.right) + " " + (height + margin.top + margin.bottom))
      .attr("preserveAspectRatio", "xMinYMin")
      .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

    # clipping rect
    @svg.append("defs").append("clipPath")
      .attr("id", "clip")
      .append("rect")
      .attr("width", width)
      .attr("height", height)

    # border
    @svg.append("rect")
      .attr("width", width)
      .attr("height", height)
      .attr("fill", "none")
      .attr("vector-effect", "non-scaling-stroke")
      .attr("stroke", "#AAAAAA")
      .attr("stroke-width", 0.4)

    @xScale = d3.scale.linear()
      .domain([0, 10])
      .range([0, width])

    @yScale = d3.scale.linear()
      .domain([0, 10])             # TODO: support changes
      .range([0, height])

    @lineGenerator = d3.svg.line()
      .x( (d) -> @xScale(d[0]) )
      .y( (d) -> @yScale(d[1]) )

    @initData = [
      [5, 0]
      [5, 0.75]
      [4, 1]
      [6, 1.5]
      [4, 2]
      [6, 2.5]
      [4, 3]
      [6, 3.5]
      [4, 4]
      [5, 4.25]
      [5, 6]
    ]

    cliper = @svg.append("g").attr("clip-path", "url(#clip)")

    @path = cliper.append("path")
      .attr("d", @lineGenerator(@initData))
      .attr("stroke", "blue")
      .attr("stroke-width", 2)
      .attr("fill", "none")

    @circle = cliper.append("circle")
      .attr("cx", @xScale(5))
      .attr("cy", @yScale(6))
      .attr("r", @xScale(1))

  resize: () ->
    size = $("##{@graphID}").width()
    d3.select("##{@graphID} svg")
      .attr("width", size)
      .attr("height", size)

  update: (pos) ->
    @circle.transition()
        .duration(50)
        .ease("linear")
        .attr("transform", "translate(0, #{(@yScale(pos*2))})")

    @data = @initData.map (p) -> [p[0], (p[1] + 2 * pos * (p[1] / 6.0))]

    @path.transition()
      .duration(50)
      .ease("linear")
      .attr("d", @lineGenerator(@data))