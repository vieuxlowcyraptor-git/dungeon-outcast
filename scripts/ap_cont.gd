extends HFlowContainer

@onready var timer: Timer = $Timer

var attackAp = 0
var defenseAp = 0
var magicAp = 0
var otherAp = 0
var apArray = []
func init(A_AP,D_AP,M_AP,O_AP):
	attackAp = A_AP
	defenseAp = D_AP
	magicAp = M_AP
	otherAp = O_AP
	for i in range(A_AP):
		var ap:TextureProgressBar = load("res://scene/attack_progress_ap.tscn").instantiate()
		add_child(ap)
		apArray.append(ap)
		print("adding attacks")
	for i in range(D_AP):
		var ap:TextureProgressBar = load("res://scene/defense_progress_ap.tscn").instantiate()
		add_child(ap)
		apArray.append(ap)
		print("adding defense")
	$Timer.start()
	



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	init(3,2,0,0)
	pass # Replace with function body.

func _on_timer_timeout() -> void:
	for i in apArray.size():
		var ap:TextureProgressBar = apArray[i]
		if ap.value>0:
			apArray[i].value-=1
			break
	
