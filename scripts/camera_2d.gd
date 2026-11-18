extends Camera2D

const ZOOM_MIN = Vector2(2,2)
const ZOOM_MAX = Vector2(0.1,0.1)
const ZOOM_SPEED = 0.5
var zoom_in = false
var zoom_out = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	make_current()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_released("ZOOM_UP") and zoom > ZOOM_MAX:
		zoom = lerp(zoom, zoom - Vector2(0.1,0.1), ZOOM_SPEED)
	if Input.is_action_just_released("ZOOM_DOWN") and zoom < ZOOM_MIN:
		zoom = lerp(zoom, zoom + Vector2(0.1,0.1), ZOOM_SPEED)
	#if zoom_in == true :
		#yield(get_tree().create_timer(0.10), "timeout")
		#zoom_in = false
	#if zoom_out == true :
		#yield(get_tree().create_timer(0.10), "timeout")
		#zoom_out = false
