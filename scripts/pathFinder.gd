class_name PathFinder 
extends Node

const SPEED = 100.0
var startCoord:Vector2
var targetCoord:Vector2
var lastCoord
var started = false
@onready var fairy: CharacterBody2D = $PathFairy
@onready var timer: Timer = $Timer
@onready var nav: NavigationAgent2D = $PathFairy/NavigationAgent2D
@onready var wall: TileMapLayer = $"../wall"

func _physics_process(delta: float) -> void:	
	if started:
		var nextCoord = fairy.to_local(nav.get_next_path_position())
		fairy.velocity =nextCoord.normalized()*SPEED
		fairy.move_and_slide()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func start(start,target) -> void:
	startCoord=start
	targetCoord=target
	fairy.position = start
	nav.debug_enabled=false
	nav.target_position = target	
	started=true

func _on_navigation_agent_2d_navigation_finished() -> void:
	started=false
	fairy.hide()
	print("reached")
