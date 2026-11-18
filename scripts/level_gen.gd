extends Node2D
@onready var ground: TileMapLayer = $ground
@onready var wall: TileMapLayer = $wall
@onready var misc: TileMapLayer = $misc
#@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var player: Node2D = $Player/player
@onready var path_finder: PathFinder = $PathFinder


const MAX_Y = 30
const MAX_X = 30
const MAX_L_PATH = MAX_X*3
const MAX_L_BRANCH = MAX_X
const NB_BRANCH_RANGE = [30,40]
const log = true
const GROUND = Vector2i(1,0)
const CORRIDOR = Vector2i(10,1)
const TERRAIN_WALL = [0,1]
const TERRAIN_CORRIDOR = [0,0]
const DUNGEON_TILE = preload("res://scene/dungeon_tile.tres")
var RNG = RandomNumberGenerator.new()
var PH:PathHandler
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	wall.navigation_enabled=false
	ground.clear()
	wall.clear()
	misc.clear()
	var time_start = Time.get_ticks_msec()
	############################################## add start points
	PH = PathHandler.new(MAX_X,MAX_Y)
	############################################## add structures
	reservePattern(DUNGEON_TILE,[5,6,7,8,9,10],3)
	#obstacle
	reservePattern(DUNGEON_TILE,[0,1,2,3,4],3)
	time_start=PH.print_time("pattern",time_start)	
	##############################################PATH GENERATION
	PH.link_create_branches(MAX_L_PATH) 
	#PH.grid_to_string()
	PH.link_create_secondary(NB_BRANCH_RANGE[0],NB_BRANCH_RANGE[1],MAX_L_BRANCH)
	#PH.grid_to_string()
	PH.link_merge_connections()
	time_start=PH.print_time("branches",time_start)
	#remove generated for all cell exept walls
	#PH.grid_reset_cell_data("generated","wall",false)
	# trying to fix broken maze
	PH.path_build_links()
	time_start=PH.print_time("links",time_start)
	PH.print_str("[color=blue]"+str(PH.links.size()-1)+" unmerged link") 	
	############################################## fill using pathHandler
	generatePattern(wall)
	time_start=PH.print_time("print pattern",time_start)
	fillWall(MAX_X+2,MAX_Y+2)	
	time_start=PH.print_time("print walls",time_start)
	fillGround(MAX_X+2,MAX_Y+2)
	PH.grid_to_string()
	var startCoord = wall.map_to_local(PH.START)
	var endCoord = wall.map_to_local(PH.END)
	PH.print_str("start: "+str(startCoord)+ " end: "+"start : "+str(endCoord))
	player.position = startCoord
	path_finder.start(startCoord,endCoord)
	wall.navigation_enabled=true
	#TODO show coordinate in UI
	#TODO fog of war
	#TODO menu and save
	#TODO generate before drawing
	

func reservePattern(tileSet:TileSet,roomIds:Array[int],attempts:int):
	for room in roomIds:
		var pattern = tileSet.get_pattern(room)
		var success = PH.grid_reserve_pattern(pattern,CORRIDOR,attempts)
		if !success:
			PH.print_str("[color=red]gen room["+str(room)+"] failed")
		pass
func generatePattern(tileLayer: TileMapLayer):
	var patterns = PH.patterns.keys()
	for coord in patterns:
		tileLayer.set_pattern(coord,PH.patterns[coord])

func fillWall(X:int,Y:int):
	var walls:Array[Vector2i]
	var corridors:Array[Vector2i]
	for x in range(-X,X):
		for y in range(-Y,Y):			
			var coord = Vector2i(x,y);
			if !PH.grid.has(coord) || PH.grid_cell_wall(coord):
				walls.append(coord)
			if PH.grid.has(coord) && !PH.grid_cell_wall(coord):
				corridors.append(coord)
	if !walls.is_empty():
		wall.set_cells_terrain_connect(walls,TERRAIN_WALL[0],TERRAIN_WALL[1],false)
	if !corridors.is_empty():
		wall.set_cells_terrain_connect(corridors,TERRAIN_CORRIDOR[0],TERRAIN_CORRIDOR[1],false)

func fillGround(X:int,Y:int):
	var targets:Array[Vector2i]
	for x in range(-X,X):
		for y in range(-Y,Y):
			targets.append(Vector2i(x,y))
	if targets.size()>0:
		ground.set_cells_terrain_connect(targets,GROUND.x,GROUND.y,false)
	ground.set_cell(PH.START,1,Vector2i(0,5))
	ground.set_cell(PH.END,1,Vector2i(0,5))

func getRandSpacedCoord(region:Vector4i,coord:Vector2i,space=5):
	while true:
		var x = RNG.randi_range(region.x,region.y)
		var y = RNG.randi_range(region.z,region.w)
		var newCoord = Vector2i(x,y)
		if newCoord.distance_squared_to(coord)>=space:
			return newCoord

#func generatePattern(layer:TileMapLayer,pattern:TileMapPattern,startCoord:Vector2i):
	#layer.set_pattern(startCoord,pattern)
	#var links:Array[int]
	#for coord in pattern.get_used_cells():
		#if pattern.get_cell_atlas_coords(coord)==Vector2i(10,1) && pattern.get_cell_alternative_tile(coord)==1:
			#links.append(PH.link_add(startCoord+coord,"room"))
	#PH.link_connect(links)

func isCellFree(layer:TileMapLayer,coord:Vector2i):
	var free = true
	var data = layer.get_cell_tile_data(coord)
	if data:
		free = false
	return free
func isCellCorridor(layer:TileMapLayer,coord:Vector2i):
	var corridor = false
	var data = layer.get_cell_tile_data(coord)
	if data.terrain_set==0 && data.terrain==0:
		corridor = true
	return corridor

	

func colorMisc(coord,color=-1):
	#TODO visual for generated
	if color!=-1:
		pass
		#misc.set_cell(coord,0, Vector2i(9,2),color)
	else:
		misc.erase_cell(coord)
