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
const CORRIDOR = Vector2i(0,0)
const WALL = Vector2i(0,1)
const DUNGEON_TILE = preload("res://scene/dungeon_tile.tres")
var RNG = RandomNumberGenerator.new()
enum Direction {N,S,E,W,NE,NW,SE,SW,X }
var DIREC_DICT:Dictionary= {
	Direction.N:{"vect":Vector2i(0,-1),"region":Vector4i(-MAX_X/2,MAX_X/2,MAX_Y/2,MAX_Y/1),"neg":Direction.S},
	Direction.S:{"vect":Vector2i(0,1),"region":Vector4i(-MAX_X/2,MAX_X/2,-MAX_Y/1,-MAX_Y/2),"neg":Direction.N},
	Direction.E:{"vect":Vector2i(1,0),"region":Vector4i(MAX_X/2,MAX_X/1,-MAX_Y/2,MAX_Y/2),"neg":Direction.W},
	Direction.W:{"vect":Vector2i(-1,0),"region":Vector4i(-MAX_X/1,-MAX_X/2,-MAX_Y/2,MAX_Y/2),"neg":Direction.E},
	Direction.NE:{"vect":Vector2i(1,-1),"region":Vector4i(MAX_X/2,MAX_X/1,MAX_Y/2,MAX_Y/1),"neg":Direction.SW},
	Direction.NW:{"vect":Vector2i(-1,-1),"region":Vector4i(-MAX_X/1,-MAX_X/2,MAX_Y/2,MAX_Y/1),"neg":Direction.SE},
	Direction.SE:{"vect":Vector2i(1,1),"region":Vector4i(MAX_X/2,MAX_X/1,-MAX_Y/1,-MAX_Y/2),"neg":Direction.NW},
	Direction.SW:{"vect":Vector2i(-1,1),"region":Vector4i(-MAX_X/1,-MAX_X/2,-MAX_Y/1,-MAX_Y/2),"neg":Direction.NE},
	Direction.X:{"vect":Vector2i(0,0),"region":Vector4i(-MAX_X/2,MAX_X/2,-MAX_Y/2,MAX_Y/2),"neg":Direction.X},
}
var REGIONS:Dictionary
var PATH_HANDLER:PathHandler
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	wall.navigation_enabled=false
	ground.clear()
	wall.clear()
	misc.clear()
	var time_start = Time.get_ticks_msec()
	PATH_HANDLER = PathHandler.new(MAX_X,MAX_Y)
	############################################## add start points
	generateStairs()
	############################################## add structures
	#generateObstacles([0,1,2,3,4])	
	generateRooms([5,6,7,8,9,10]) #5,6,7,8
	generateObstacles([0,1,2,3,4])	
	# mark all used cell as generated
	markUsedAsGenerated()
	time_start=printTime("pattern",time_start)
	##############################################
	#fill the remaining wall and ground
	prefillGround(MAX_X+2,MAX_Y+2)
	time_start=printTime("prefillGround",time_start)
	##############################################PATH GENERATION
	generateMainBranches()
	time_start=printTime("mainbranch",time_start)
	generateSecBranches()	
	time_start=printTime("secBranch",time_start)
	for link in PATH_HANDLER.links:
		PATH_HANDLER.link_merge_connection(link)	
	PATH_HANDLER.grid_reset_cell_data("generated","wall",false)
	time_start=printTime("mergeBranches",time_start)
	# trying to fix broken maze
	generateLinkPath()
	time_start=printTime("links",time_start)
	printLog("[color=blue]"+str(PATH_HANDLER.links.size()-1)+" unmerged link") 
	prefillWall(MAX_X+2,MAX_Y+2)	
	time_start=printTime("walls",time_start)
	
	var startCoord = wall.map_to_local(PATH_HANDLER.startCoord)
	var endCoord = wall.map_to_local(PATH_HANDLER.endCoord)
	print("start: "+str(startCoord)+ " end: "+"start : "+str(endCoord))
	player.position = startCoord
	path_finder.start(startCoord,endCoord)
	wall.navigation_enabled=true
	#TODO show coordinate in UI
	#TODO fog of war
	#TODO menu and save
	#TODO generate before drawing
	


func checkLimits(coord:Vector2i):
	return MAX_X>=coord.x && -MAX_X<=coord.x && MAX_Y>=coord.y && -MAX_Y<=coord.y
func getPathableWall(path:Array[Vector2i],pos:int,link)->Array[Dictionary]:
	var walls:Array[Dictionary]
	var coord = path[pos]
	for dir in 4:
		var direction = Direction[Direction.keys()[dir]]
		if checkWallDirection(coord,direction,true):
			walls.append({
				"coord":coord+DIREC_DICT[direction].vect,
				"dir":direction,
				"path":path,
				"link":link
			})		
	return walls
	

func prefillWall(X:int,Y:int):
	var usedCells = wall.get_used_cells()
	var targets:Array[Vector2i]
	for x in range(-X,X):
		for y in range(-Y,Y):			
			var coord = Vector2i(x,y);
			if usedCells.has(coord):
				continue	
			if isCellFree(wall,coord):
				targets.append(coord)
				PATH_HANDLER.grid_set_cell_data(coord,false,false,true)
			else:
				PATH_HANDLER.grid_set_cell_data(coord,false,false,!isCellCorridor(wall,coord))	
	if targets.size()>0:
		wall.set_cells_terrain_connect(targets,WALL.x,WALL.y,false)

func prefillGround(X:int,Y:int):
	var targets:Array[Vector2i]
	for x in range(-X/2,X/2):
		for y in range(-Y/2,Y/2):			
			var coord = Vector2i(x,y);
			if isCellFree(ground,coord):
				targets.append(coord)
	if targets.size()>0:
		ground.set_cells_terrain_connect(targets,GROUND.x,GROUND.y,false)
		
func drawCorridor(coord:Vector2i,dir=Direction.X):
	PATH_HANDLER.grid_set_cell_data(coord,true,true,false)
	wall.set_cells_terrain_connect([coord],CORRIDOR.x, CORRIDOR.y, false)
	if dir!=Direction.X:
		if dir in [Direction.N,Direction.S]:
			if dir==Direction.N:
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.SE].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.SW].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.S].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.S].vect+DIREC_DICT[Direction.SE].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.S].vect+DIREC_DICT[Direction.SW].vect,null,true)
			else:	
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.NE].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.NW].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.N].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.N].vect+DIREC_DICT[Direction.NE].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.N].vect+DIREC_DICT[Direction.NW].vect,null,true)
		else:
			if dir==Direction.E:
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.NW].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.SW].vect,null,true)	
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.W].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.W].vect+DIREC_DICT[Direction.NW].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.W].vect+DIREC_DICT[Direction.SW].vect,null,true)
			else:	
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.NE].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.SE].vect,null,true)	
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.E].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.E].vect+DIREC_DICT[Direction.NE].vect,null,true)
				PATH_HANDLER.grid_set_cell_data(coord+DIREC_DICT[Direction.E].vect+DIREC_DICT[Direction.SE].vect,null,true)
		
func pathToConnection(start,target):
	#TODO visual for generated
	colorMisc(start,4)
	colorMisc(target,4)	
	var newPath:Array[Vector2i]
	var current = start
	var dir:Direction= Direction.X 
	#TODO use pathing isntead of direction 
	while true:
		dir = findDirection(current,target,newPath)	
		if dir!=Direction.X:
			current=current+DIREC_DICT[dir].vect		
			newPath.append(current)
			if current.distance_squared_to(target)==1:
				break
		else:
			break
	return newPath
func findDirection(source,target,paths)->Direction:
	var delta = target-source
	var possibleDirs=[Direction.N,Direction.S,Direction.E,Direction.W]
	var favoriteDirs=[]
	#remove already pathed and impossible dir
	for newDir in possibleDirs.duplicate():
		#|| paths.has(source+DIREC_DICT[newDir].vect)
		if !checkDirection(source,newDir) :
			possibleDirs.erase(newDir)
	if source.x<target.x :
		favoriteDirs.append(Direction.E)
	elif source.x>target.x:
		favoriteDirs.append(Direction.W)
	if source.y<target.y :
		array_append_dedup(favoriteDirs,Direction.S)
	elif source.y>target.y:
		array_append_dedup(favoriteDirs,Direction.N)
	#possibleDirs.erase(result)
	if !favoriteDirs.is_empty():	
		for dir in favoriteDirs:			
			possibleDirs.erase(DIREC_DICT[dir].neg)	
			if paths.has(source+DIREC_DICT[dir].vect):
				possibleDirs.erase(dir)				
	var result=Direction.X
	#if favorite are not in possibles
	if !favoriteDirs.is_empty() && !possibleDirs.is_empty():
		if !arrays_contains_any(possibleDirs,favoriteDirs):
			var newDir = possibleDirs.pick_random()
			printLog("[color=blue]"+str(source)+"->"+str(target)+" dir blocked, try dir "+str(Direction.keys()[newDir]))
			return newDir
		var fav =  arrays_intersect(possibleDirs,favoriteDirs).pick_random()
		printLog("[color=blue]"+str(source)+"->"+str(target)+" dir "+str(Direction.keys()[fav]))
		return fav
	if !favoriteDirs.is_empty() :
		result = favoriteDirs.pick_random()
		printLog("[color=blue]"+str(source)+"->"+str(target)+" forcing dir "+str(Direction.keys()[result]))
		return result
	printLog("[color=blue]"+str(source)+"->"+str(target)+" dir failed")
	return Direction.X

func getWallDirectionFromVector(source,dirVector)-> Direction:
	if dirVector:
		for dir in DIREC_DICT:
			if dirVector && DIREC_DICT[dir].vect == dirVector:
				if checkDirection(source,dir):
					return dir		
	return Direction.X
func getDirectionFromInt(idx:int):
	return DIREC_DICT[Direction[Direction.keys()[idx]]]
func getRandCoord(region:Vector4i,size=Vector2i(0,0)):
	var x = RNG.randi_range(region.x,region.y-size.x)
	var y = RNG.randi_range(region.z,region.w-size.y)
	return Vector2i(x,y)

func getRandSpacedCoord(region:Vector4i,coord:Vector2i,space=5):
	while true:
		var x = RNG.randi_range(region.x,region.y)
		var y = RNG.randi_range(region.z,region.w)
		var newCoord = Vector2i(x,y)
		if newCoord.distance_squared_to(coord)>=space:
			return newCoord

func generatePattern(layer:TileMapLayer,pattern:TileMapPattern,startCoord:Vector2i):
	layer.set_pattern(startCoord,pattern)
	var links:Array[int]
	for coord in pattern.get_used_cells():
		if pattern.get_cell_atlas_coords(coord)==Vector2i(10,1) && pattern.get_cell_alternative_tile(coord)==1:
			links.append(PATH_HANDLER.link_add(startCoord+coord,"room"))
	PATH_HANDLER.link_connect(links)

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

func checkFreeSpace(layer:TileMapLayer,startCoord:Vector2i,size:Vector2i) -> bool :
	var free = true
	var endCoord = startCoord + size
	for x in range(startCoord.x-2,endCoord.x+2):
		for y in range(startCoord.y-2,endCoord.y+2):
			var data = layer.get_cell_tile_data(Vector2i(x,y))
			if data:
				free = false
				break
	return free

func buildPath(startCoord:Vector2i,size:int=10,color=-1) -> Array[Vector2i]:
	var path:Array[Vector2i] = [startCoord]
	for i in size:
		var weightArray=[]
		weightArray.append(float(checkPathDirection(path[i],Direction.N)))
		weightArray.append(float(checkPathDirection(path[i],Direction.S)))
		weightArray.append(float(checkPathDirection(path[i],Direction.E)))
		weightArray.append(float(checkPathDirection(path[i],Direction.W)))
		var vec = RNG.rand_weighted(weightArray)
		if vec == -1:
			#no more path possible
			if i>0:
				printLog("[color=green]new branch at "+str(startCoord)+" l:"+str(path.size()))
			break
		var dir = getDirectionFromInt(vec)
		var coord = path[i]+dir.vect;
		drawCorridor(coord,DIREC_DICT.find_key(dir))
		colorMisc(coord,color)	
		path.append(coord)
	return path
#check direction from cooed
func checkPathDirection(coord:Vector2i,dir:Direction)->bool:
	var result = false
	var newCoord = coord+DIREC_DICT[dir].vect
	if !PATH_HANDLER.is_cell_generated(newCoord) && !PATH_HANDLER.is_cell_locked(newCoord) && checkLimits(newCoord):
		result = true
	return result
func checkWallDirection(coord:Vector2i,dir:Direction,isPathable:bool=false)->bool:
	var newCoord = coord+DIREC_DICT[dir].vect
	if !PATH_HANDLER.is_cell_generated(newCoord) && !PATH_HANDLER.is_cell_locked(newCoord) && checkLimits(newCoord):
		if isPathable:
			return checkWallDirection(newCoord,dir)
		else:
			return true
	return false
func checkDirection(coord:Vector2i,dir:Direction)->bool:
	var newCoord = coord+DIREC_DICT[dir].vect
	if !PATH_HANDLER.is_cell_locked(newCoord) && checkLimits(newCoord):
		return true
	return false


func generateStairs():
	var startLocation = getDirectionFromInt(RNG.randi_range(0,7))
	var endLocation = DIREC_DICT[startLocation.neg]
	var startStair = getRandCoord(startLocation.region)
	var endStair = getRandCoord(endLocation.region)
	drawCorridor(startStair)
	drawCorridor(endStair)
	PATH_HANDLER.link_add(startStair,"start")
	PATH_HANDLER.link_add(endStair,"end")
	#TODO color for start
	ground.set_cell(startStair,1,Vector2i(0,5))
	ground.set_cell(endStair,1,Vector2i(0,5))
func generateRooms(roomIds):
	generatePattern(wall, DUNGEON_TILE.get_pattern(4),Vector2i(-8,-3))
	for room in roomIds:
		var pattern = DUNGEON_TILE.get_pattern(room)
		var startCoord
		var success = false
		for attempt in 5:
			startCoord = PATH_HANDLER.getRandCoord(Vector4i(-MAX_X,MAX_X,-MAX_Y,MAX_Y),pattern.get_size()+Vector2i(1,1))
			if checkFreeSpace(wall,startCoord,pattern.get_size()):
				generatePattern(wall,pattern,startCoord)
				success = true 
				break
		if success:
			printLog("[color=red]gen room["+str(room)+"] at "+ str(startCoord)+" size "+str(pattern.get_size()))
		else:
			printLog("[color=red]gen room["+str(room)+"] failed")
func generateObstacles(obsIds):
	for obs in obsIds:
		var pattern = DUNGEON_TILE.get_pattern(obs)			
		var nbSuccess = 0
		for attempt in 10:
			var startCoord = getRandCoord(Vector4i(-MAX_X,MAX_X,-MAX_Y,MAX_Y),pattern.get_size()+Vector2i(1,1))
			if checkFreeSpace(wall,startCoord,pattern.get_size()):
				generatePattern(wall,pattern,startCoord)
				nbSuccess = nbSuccess+1
				if nbSuccess>2:
					break
		if nbSuccess>0:
			printLog("[color=red]gen obs["+str(obs)+"]#"+str(nbSuccess)+" size "+str(pattern.get_size()))
		else:
			printLog("[color=red]gen obs["+str(obs)+"] failed")

func markUsedAsGenerated():
	#var corridors = wall.get_used_cells_by_id(0,Vector2i(10,1))
	var usedCells = wall.get_used_cells()
	for coord in usedCells:
		#if !corridors.has(coord):
		PATH_HANDLER.grid_set_cell_data(coord,true,true,true)
		colorMisc(coord,1)

func colorMisc(coord,color=-1):
	#TODO visual for generated
	if color!=-1:
		pass
		#misc.set_cell(coord,0, Vector2i(9,2),color)
	else:
		misc.erase_cell(coord)
	
func generateMainBranches():
	for link in PATH_HANDLER.links:
		var start = PATH_HANDLER.links[link].path[0]
		PATH_HANDLER.link_set_path(link,buildPath(start,MAX_L_PATH,2))
func generateSecBranches():
	#add a random number of branch
	var nbBranches = RNG.randi_range(NB_BRANCH_RANGE[0],NB_BRANCH_RANGE[1])
	for i in nbBranches:
		#var branchId = RNG.randi_range(0,linkables.size()-1)		
		var posStart:Array[Dictionary]
		#TODO move in handler
		# search every possible pathable wall
		for link in PATH_HANDLER.links:
			var path = PATH_HANDLER.link_get_path(link)
			var possibleMin = min(3,path.size()-2)
			var possibleMax = path.size()-2
			if possibleMin<=possibleMax:
				for pos in range(possibleMin,possibleMax):
					var walls=getPathableWall(path,pos,link)
					if !walls.is_empty():
						posStart.append_array(walls)
		if !posStart.is_empty():
			var start = posStart.pick_random()
			drawCorridor(start.coord,start.dir)
			colorMisc(start.coord,3)			
			PATH_HANDLER.link_add_path(start.link,buildPath(start.coord,MAX_L_BRANCH,3))
func generateLinkPath():
	var unconnecteds = PATH_HANDLER.link_get_unconnected(PATH_HANDLER.START)	
	var attemptLeft = unconnecteds.size()+2
	var failed = []
	var previousPair
	while !unconnecteds.is_empty():
		var pair = getRandomMinConnection(unconnecteds,previousPair)		
		if !pair || pair==previousPair:
			continue
		previousPair=pair
		printLog("[color=blue]link"+str(pair.linkId)+" "+str(pair.start)+"-"+str(pair.end) +" min dist "+str(pair.dist))
		var path = pathToConnection(pair.start,pair.end)
		if path:
			wall.set_cells_terrain_connect(path,CORRIDOR.x, CORRIDOR.y, false)			
			for coord in path:
				PATH_HANDLER.grid_set_cell_data(coord,true,true,false)
				colorMisc(coord,4)
			PATH_HANDLER.link_add_path(pair.linkId,path)	
			PATH_HANDLER.link_merge_connection(pair.linkId)
			unconnecteds = PATH_HANDLER.link_get_unconnected(PATH_HANDLER.START)
func getRandomMinConnection(unconnecteds:Array,previousPair):
	var pairs = []
	var minDist:int=-1
	for uncon in unconnecteds:
		var conPath= PATH_HANDLER.link_get_other_path(uncon)
		var pairsFound = PATH_HANDLER.link_find_nearest_path(uncon,conPath)
		for pair in pairsFound:
			if minDist==pair.dist:
				pairs.append(pair)
			elif minDist==-1 || minDist>pair.dist:
				minDist = pair.dist
				pairs.clear()
				pairs.append(pair)
	assert(!pairs.is_empty(),"unconnected but no coord ?")
	return pairs.pick_random()

func printTime(label:String,time_start:int):
	var time_now = Time.get_ticks_msec()
	var time_elapsed = time_now - time_start
	print(label+": "+str(time_elapsed))
	return time_now
func printLog(label:String):
	if log: print_rich(label)
func arrays_contains_any(array1, array2):
	for item in array2:
		if array1.has(item):
			return true		
	return false
func arrays_intersect(array1, array2):
	var intersection = []
	for item in array1:
		if array2.has(item):
			intersection.append(item)
	return intersection
func arrays_append_dedup(array1:Array, array2:Array):
	for item in array1:
		array_append_dedup(array1,item)
func array_append_dedup(array1:Array, obj):
	if array1.is_empty() || !array1.has(obj):
		array1.append(obj)
