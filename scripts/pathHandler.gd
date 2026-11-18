class_name PathHandler
extends Node

#const START = 0
var links={}
var grid={}
var patterns={}
var obstacle={}
var reacheablePath

var START
var END
var MAX_X = 30
var MAX_Y = 30
var RNG = RandomNumberGenerator.new()
enum Direction {N,S,E,W,NE,NW,SE,SW,X}
var CARDINAL = [Direction.N,Direction.S,Direction.E,Direction.W]
var DIRECTIONS:Dictionary= {
	Direction.N:{"vect":Vector2i(0,-1),"neg":Direction.S},
	Direction.S:{"vect":Vector2i(0,1),"neg":Direction.N},
	Direction.E:{"vect":Vector2i(1,0),"neg":Direction.W},
	Direction.W:{"vect":Vector2i(-1,0),"neg":Direction.E},
	Direction.NE:{"vect":Vector2i(1,-1),"neg":Direction.SW},
	Direction.NW:{"vect":Vector2i(-1,-1),"neg":Direction.SE},
	Direction.SE:{"vect":Vector2i(1,1),"neg":Direction.NW},
	Direction.SW:{"vect":Vector2i(-1,1),"neg":Direction.NE},
	Direction.X:{"vect":Vector2i(0,0),"neg":Direction.X},
}
var REGIONS:Dictionary

func _init(_max_x:int,_max_y:int):
	MAX_X = _max_x
	MAX_Y = _max_y
	REGIONS = {
		Direction.N:Vector4i(-MAX_X/2,MAX_X/2,MAX_Y/2,MAX_Y/1),
		Direction.S:Vector4i(-MAX_X/2,MAX_X/2,-MAX_Y/1,-MAX_Y/2),
		Direction.E:Vector4i(MAX_X/2,MAX_X/1,-MAX_Y/2,MAX_Y/2),
		Direction.W:Vector4i(-MAX_X/1,-MAX_X/2,-MAX_Y/2,MAX_Y/2),
		Direction.NE:Vector4i(MAX_X/2,MAX_X/1,MAX_Y/2,MAX_Y/1),
		Direction.NW:Vector4i(-MAX_X/1,-MAX_X/2,MAX_Y/2,MAX_Y/1),
		Direction.SE:Vector4i(MAX_X/2,MAX_X/1,-MAX_Y/1,-MAX_Y/2),
		Direction.SW:Vector4i(-MAX_X/1,-MAX_X/2,-MAX_Y/1,-MAX_Y/2),
		Direction.X:Vector4i(-MAX_X/2,MAX_X/2,-MAX_Y/2,MAX_Y/2),
	}
	#pick random edge
	var rndDir = [Direction.N,Direction.NW,Direction.E,Direction.NE,Direction.W,Direction.SW,Direction.S,Direction.SE].pick_random()
	var startRegion = REGIONS[rndDir];
	var endRegion =  REGIONS[DIRECTIONS[rndDir].neg]
	START = grid_rand_coord(startRegion)
	END = grid_rand_coord(endRegion)
	grid_set_cell_data(START,true,true,false,true,"start")
	grid_set_cell_data(END,true,true,false,true,"end")
	link_add(START,"START")
	link_add(END,"END")

func grid_rand_coord(region:Vector4i,size=Vector2i(0,0)):
	var x = RNG.randi_range(region.x,region.y-size.x)
	var y = RNG.randi_range(region.z,region.w-size.y)
	return Vector2i(x,y)
	
func grid_reserve_pattern(pattern:TileMapPattern,corridorTile:Vector2i,attemps:int=3)->bool:
	var startCoord
	var success = false
	for attempt in attemps:
		startCoord = grid_rand_coord(Vector4i(-MAX_X,MAX_X,-MAX_Y,MAX_Y),pattern.get_size()+Vector2i(1,1))
		if grid_check_space(startCoord,pattern.get_size()):
			grid_reserve_pattern_coord(pattern,startCoord,corridorTile)
			success = true 
			break
	if success:		
		patterns[startCoord]=pattern
		return true
	return false	
func grid_check_space(startCoord:Vector2i,size:Vector2i) -> bool :
	var free = true
	var endCoord = startCoord + size
	for x in range(startCoord.x-2,endCoord.x+2):
		for y in range(startCoord.y-2,endCoord.y+2):
			if grid.has(Vector2i(x,y)):
				free = false
				break
	return free
func grid_reserve_pattern_coord(pattern:TileMapPattern,startCoord:Vector2i,corridorTile:Vector2i):
	var links:Array[int]
	for coord in pattern.get_used_cells():
		var realCoord = startCoord+coord
		var atlasCoord = pattern.get_cell_atlas_coords(coord);
		var isCorridor = corridorTile==atlasCoord;
		var linkable = isCorridor && pattern.get_cell_alternative_tile(coord)==1
		grid_set_cell_data(realCoord,true,true,!isCorridor,linkable)
		if linkable:
			links.append(link_add(realCoord,"room"))
	link_connect(links)


################## GRID ###########################
func grid_get_cell(coord:Vector2i):
	return grid.get_or_add(coord,DataLayer.new())

func grid_set_cell_data(coord:Vector2i,locked=null,generated=null,wall=null,linkable=null,type=null):
	var cell = grid_get_cell(coord)
	if locked!=null:
		cell.locked=locked
	if generated!=null:
		cell.generated=generated
	if wall!=null:
		cell.wall=wall
	if linkable!=null:
		cell.linkable=linkable
	if type!=null:
		cell.type=type
func grid_get_cell_data(coord:Vector2i,flag:String):
	return grid.has(coord) && grid[coord][flag]==true
func grid_reset_cell_data(flag:String,excludeFlag,excludeValue):
	for cell in grid:
		if excludeFlag && excludeValue && grid[cell][excludeFlag]==excludeValue:
			continue
		grid[cell][flag]=false
func grid_cell_locked(coord):
	return grid_get_cell_data(coord,"locked")
func grid_cell_wall(coord):
	return grid_get_cell_data(coord,"wall")
func grid_cell_generated(coord):
	return grid_get_cell_data(coord,"generated")
func grid_cell_entrance(coord):
	return grid.has(coord) && ["start","end"].has(grid[coord]["type"])

func grid_check_limits(coord:Vector2i):
	return MAX_X>=coord.x && -MAX_X<=coord.x && MAX_Y>=coord.y && -MAX_Y<=coord.y
################## LINK ###########################
func link_add(coord:Vector2i,type=null)->int:
	var id = links.size()
	links[id]={"type":type,"connected":[],"path":[coord]}
	return id
func link_add_array(coords:Array[Vector2i],type=null)->Array[int]:
	var result:Array[int]
	for coord in coords:
		result.append(link_add(coord,type))
	return result
func link_connect(conList:Array[int]):
	for con1 in conList:
		for con2 in conList:
			if con1!=con2 && !links[con1].connected.has(con2):
				links[con1].connected.append(con2)

func link_set_path(linkId:int,path:Array[Vector2i]):
	links[linkId].path=path
func link_add_path(linkId:int,paths:Array[Vector2i]):
	for coord in paths:
		if links[linkId].has("path") && !links[linkId].path.has(coord):
			links[linkId].path.append(coord)
func link_get_path(linkId:int):
	return links[linkId].path
func link_merge_connections():
	for link in links:
		link_merge_connection(link)		
func link_merge_connection(linkId:int):
	var toBeMerged:Array[int]
	for linkId2 in links:
		if linkId2!=linkId:
			if link_is_path_connected(linkId,linkId2):
				if !toBeMerged.has(linkId2):
					toBeMerged.append(linkId2)
				for con in links[linkId2].connected:				
					if !toBeMerged.has(con) && con!=linkId:
						toBeMerged.append(con)
	
	if !toBeMerged.is_empty():		
		if toBeMerged.has(START):
			toBeMerged.erase(START)
			toBeMerged.append(linkId)
			linkId=START
		#markAsConnected(conLinks)
		for mergeId in toBeMerged:
			if links.has(linkId) && links.has(mergeId):				
				#add path to first 
				links[linkId].connected.erase(mergeId)
				link_add_path(linkId,links[mergeId].path)
				links.erase(mergeId)
func link_is_path_connected(linkId1:int,linkId2:int):
	if linkId1 != linkId2:
		var link1 = links[linkId1]
		var link2 = links[linkId2]
		#already connected
		if link1.connected.has(linkId2) || link2.connected.has(linkId1) :
			return true
		if link1.has("path") && link2.has("path"):
			for coord1 in link1.path:
				for coord2 in link2.path:
					if coord1==coord2 || coord1.distance_squared_to(coord2)==1:
						return true
	return false

func link_get_unconnected(linkId:int=0)->Array:
	var unlinked:Array[int]
	if links.size()>1:
		for link in links:
			if link!=linkId && !links[link].connected.has(linkId):
				unlinked.append(link)
	return unlinked
#get an array will all the path coordinate
func link_get_other_path(exclude:int):
	var fullPath=[]
	for link in links:
		if link!=exclude:
			fullPath.append_array(links[link].path)
	return fullPath

func link_find_nearest_path(linkId1:int,path2):
	var minDistance:int=-1
	var pairs:Array[Dictionary]
	for coord:Vector2i in links[linkId1].path:
		for coord2:Vector2i in path2:
			var dist = coord.distance_squared_to(coord2)
			var pair = {"linkId":linkId1,"start":coord,"end":coord2,"dist":dist}
			if minDistance == -1 || dist<minDistance:
				minDistance=dist
				pairs.clear()
				pairs.append(pair)
			elif dist==minDistance && pairs.has(pair):
				pairs.append(pair)
	return pairs

func link_create_branches(length:int):
	for link in links:
		var start = links[link].path[0]
		var paths = path_build(start,length)
		link_set_path(link,paths)
		pass
func link_create_secondary(minBranches:int,maxbranches:int,length:int):
	#add a random number of branch
	var nbBranches = RNG.randi_range(minBranches,maxbranches)
	for i in nbBranches:
		var posStart:Array[Dictionary]
		# search every possible pathable wall of all links paths
		for link in links:
			var path = link_get_path(link)
			var possibleMin = min(3,path.size()-2)
			var possibleMax = path.size()-2
			if possibleMin<=possibleMax:
				for pos in range(possibleMin,possibleMax):
					var walls=path_find_pathable(path[pos])
					if !walls.is_empty():						
						for wall in walls:
							#wall["path"] = path
							wall["link"] = link
						posStart.append_array(walls)
		if !posStart.is_empty():
			var start = posStart.pick_random()
			path_set_corridor(start.coord)
			var newCoord = path_set_corridor(start.coord,start.dir)
			var paths = path_build(newCoord,length-1)
			paths.append(newCoord)
			link_add_path(start.link,paths)
func link_closest_coord(unconnecteds:Array):
	var pairs = []
	var minDist:int=-1
	for uncon in unconnecteds:
		var conPath= link_get_other_path(uncon)
		var pairsFound = link_find_nearest_path(uncon,conPath)
		for pair in pairsFound:
			if minDist==pair.dist:
				pairs.append(pair)
			elif minDist==-1 || minDist>pair.dist:
				minDist = pair.dist
				pairs.clear()
				pairs.append(pair)
	assert(!pairs.is_empty(),"unconnected but no coord ?")
	return pairs.pick_random()
################## PATHS ###########################
func path_build(startCoord:Vector2i,size:int=10) -> Array[Vector2i]:
	var path:Array[Vector2i] = [startCoord]
	for i in size:
		var coord = path[i];
		var availablesDir=[]
		if path_check_dir_generated(coord,Direction.N): availablesDir.append(Direction.N)
		if path_check_dir_generated(coord,Direction.S): availablesDir.append(Direction.S)
		if path_check_dir_generated(coord,Direction.W): availablesDir.append(Direction.W)
		if path_check_dir_generated(coord,Direction.E): availablesDir.append(Direction.E)
		if availablesDir.is_empty():
			#no more path possible
			break
		var dir = availablesDir.pick_random();
		var newCoord = path_set_corridor(coord,dir)
		path.append(newCoord)
	return path
func path_check_dir_generated(coord:Vector2i,dir:Direction)->bool:
	var result = false
	var newCoord = coord+DIRECTIONS[dir].vect
	return !grid_cell_generated(newCoord) && !grid_cell_locked(newCoord) && grid_check_limits(newCoord)
func path_check_dir_locked(coord:Vector2i,dir:Direction)->bool:
	var newCoord = coord+DIRECTIONS[dir].vect
	return !grid_cell_locked(newCoord) && grid_check_limits(newCoord)
func path_check_dir_generate_deep(coord:Vector2i,dir:Direction)->bool:
	var newCoord = coord+DIRECTIONS[dir].vect
	return path_check_dir_generated(coord,dir) && path_check_dir_generated(newCoord,dir)
func path_find_pathable(coord:Vector2i)->Array[Dictionary]:
	var walls:Array[Dictionary]
	for dir in CARDINAL:
		if path_check_dir_generate_deep(coord,dir):
			walls.append({
				"coord":coord+DIRECTIONS[dir].vect,
				"dir":dir,
			})
	return walls
func path_build_links():
	var unconnecteds = link_get_unconnected(0)
	var attemptLeft = unconnecteds.size()+2
	var failed = []
	var previousPair
	while !unconnecteds.is_empty():
		var pair = link_closest_coord(unconnecteds)		
		if !pair || pair==previousPair:
			continue
		previousPair=pair
		print_str("[color=blue]link"+str(pair.linkId)+" "+str(pair.start)+"-"+str(pair.end) +" min dist "+str(pair.dist))
		var path = path_connection(pair.start,pair.end)
		if path:
			for coord in path:
				grid_set_cell_data(coord,true,true,false)
			link_add_path(pair.linkId,path)	
			link_merge_connection(pair.linkId)
			unconnecteds = link_get_unconnected(0)
func path_connection(start,target):
	var newPath:Array[Vector2i]
	var current = start
	var dir:Direction= Direction.X 
	while true:
		dir = path_find_direction(current,target,newPath)	
		if dir!=Direction.X:
			current=current+DIRECTIONS[dir].vect		
			newPath.append(current)
			if current.distance_squared_to(target)==1:
				break
		else:
			break
	return newPath
func path_find_direction(source,target,paths)->Direction:
	var delta = target-source
	var possibleDirs=[Direction.N,Direction.S,Direction.E,Direction.W]
	var favoriteDirs=[]
	#remove already pathed and impossible dir
	for newDir in possibleDirs.duplicate():
		#|| paths.has(source+DIREC_DICT[newDir].vect)
		if !path_check_dir_locked(source,newDir) :
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
			possibleDirs.erase(DIRECTIONS[dir].neg)	
			if paths.has(source+DIRECTIONS[dir].vect):
				possibleDirs.erase(dir)				
	var result=Direction.X
	#if favorite are not in possibles
	if !favoriteDirs.is_empty() && !possibleDirs.is_empty():
		if !arrays_contains_any(possibleDirs,favoriteDirs):
			var newDir = possibleDirs.pick_random()
			print_str("[color=blue]"+str(source)+"->"+str(target)+" dir blocked, try dir "+str(Direction.keys()[newDir]))
			return newDir
		var fav = arrays_intersect(possibleDirs,favoriteDirs).pick_random()
		print_str("[color=blue]"+str(source)+"->"+str(target)+" dir "+str(Direction.keys()[fav]))
		return fav
	if !favoriteDirs.is_empty() :
		result = favoriteDirs.pick_random()
		print_str("[color=blue]"+str(source)+"->"+str(target)+" forcing dir "+str(Direction.keys()[result]))
		return result
	print_str("[color=blue]"+str(source)+"->"+str(target)+" dir failed")
	return Direction.X
func path_set_corridor(coord:Vector2i,dir=Direction.X):
	var newCoord=coord+DIRECTIONS[dir].vect
	grid_set_cell_data(newCoord,true,true,false)
	if dir!=Direction.X:
		if dir in [Direction.N,Direction.S]:
			if dir==Direction.N:
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.SE].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.SW].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.S].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.S].vect+DIRECTIONS[Direction.SE].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.S].vect+DIRECTIONS[Direction.SW].vect,null,true)
			else:	
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.NE].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.NW].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.N].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.N].vect+DIRECTIONS[Direction.NE].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.N].vect+DIRECTIONS[Direction.NW].vect,null,true)
		else:
			if dir==Direction.E:
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.NW].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.SW].vect,null,true)	
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.W].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.W].vect+DIRECTIONS[Direction.NW].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.W].vect+DIRECTIONS[Direction.SW].vect,null,true)
			else:	
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.NE].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.SE].vect,null,true)	
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.E].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.E].vect+DIRECTIONS[Direction.NE].vect,null,true)
				grid_set_cell_data(newCoord+DIRECTIONS[Direction.E].vect+DIRECTIONS[Direction.SE].vect,null,true)
	return newCoord;

	################## UTILS ###########################
func array_dedup(array):
	var unique = []
	for item in array:
		if not unique.has(item):
			unique.append(item)
	return unique
func obj_getProps(obj):
	for prop in obj.get_property_list():
		print(prop)		
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
func print_str(label:String):
	if log: print_rich(label)
func print_time(label:String,time_start:int):
	var time_now = Time.get_ticks_msec()
	var time_elapsed = time_now - time_start
	print_str(label+": "+str(time_elapsed))
	return time_now
func grid_to_string():
	for y in range(-MAX_Y-2,MAX_Y+2):
		var line = ""
		for x in range(-MAX_X-2,MAX_X+2):
			var coord = Vector2i(x,y)
			if(grid.has(coord)):
				var locked = grid_cell_locked(coord);
				var wall = grid_cell_wall(coord);
				var linkable = grid_get_cell_data(coord,"linkable");
				if(linkable):
					line=line+"🔵"
				elif(wall):
					if locked:
						line=line+"🏿"
					else:
						line=line+"🏾"
				else:
					if locked:
						line=line+"🏼"
					else:
						line=line+"🏻"
			else:
				line=line+"🏽"
		print_rich(line)
