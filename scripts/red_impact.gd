extends AnimatedSprite2D


var ROT_SPEED = 0.01
var MIN_SCALE = 0.5
var MAX_SCALE = 1.2
var ROT_DIR = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var scale = randf_range(MIN_SCALE,MAX_SCALE)
	ROT_DIR = randi_range(-1,1)
	apply_scale(Vector2(scale,scale))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(ROT_DIR!=0) :
		var rotation = randf_range(0,ROT_DIR*ROT_SPEED)
		rotate(rotation)
	
	
