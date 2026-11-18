extends Node
class_name PLayerNode


var nextAnim = "idle"
var transTimer = null
const SPEED = 60.0
@onready var player: CharacterBody2D = %player
@onready var anim: AnimatedSprite2D = $player/anim
func _ready() -> void:
	anim.animation = "idle"
	anim.play()
	player.motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	player.wall_min_slide_angle=0
	player.max_slides=5

func _physics_process(_delta: float) -> void:
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var x := Input.get_axis("ui_left", "ui_right")
	var y := Input.get_axis("ui_up","ui_down")
	
	var speed = SPEED
	if x && y:
		speed=SPEED*0.75
	if x:		
		player.velocity.x = x * speed
		if x<0:
			anim.flip_h = true
		else:
			anim.flip_h = false
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, speed)
	if y:
		player.velocity.y = y * speed
	else:
		player.velocity.y = move_toward(player.velocity.y, 0, speed)
		
	if  anim.animation == "sneak" && player.velocity.x == 0 && player.velocity.y == 0:		
		delayed_transition("idle")
		
	if  anim.animation == "idle" && (player.velocity.x != 0 || player.velocity.y != 0):
		delayed_transition("sneak")

	player.move_and_slide()
	#for i in player.get_slide_collision_count():
	#	var collision = player.get_slide_collision(i)



func delayed_transition(next) -> void:
	nextAnim = next
	anim.play("transition")
	#create a timer
	transTimer = Timer.new()
	add_child(transTimer)
	transTimer.wait_time = 0.10
	transTimer.one_shot = true
	transTimer.connect("timeout", transitionFinished)
	transTimer.start()

func transitionFinished() -> void:
	anim.play(nextAnim)
	transTimer.queue_free()
	transTimer = null
