class_name DataLayer

extends Object

var locked=false
var generated=false
var wall=true
var linkable=false
var type:String
var trap:bool


#func _init(_locked=false,_generated=false,_wall=false):
	#locked = _locked
	#generated = _generated
	#wall = _wall
func _to_string():
	var type="wall"
	if !wall:
		type="corr"
	return type+" gen:"+str(generated)
