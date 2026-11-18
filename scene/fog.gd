extends Node2D

const LightTexture = preload("res://assets/gui/filled_gem.webp")
var fogImage = Image.new()
var fogTexture = ImageTexture.new()
var lightImage = LightTexture.get_image()
var light_offset = Vector2(LightTexture.get_width()/2, LightTexture.get_height()/2)

var width = 30
var height = 30
@onready var fog: Sprite2D = $Fog
@onready var playerNode: PLayerNode = $"../Player"

func _ready() -> void:
	fogImage.create(width, height, false, Image.FORMAT_RGBAH)
	fogImage.fill(Color.BLACK)
	lightImage.convert(Image.FORMAT_RGBAH)
	fog.scale = Vector2i(1,1)

func update_fog(new_grid_position):
	#fogImage.lock()
	#lightImage.lock()	
	var light_rect = Rect2(Vector2.ZERO, Vector2(lightImage.get_width(), lightImage.get_height()))
	fogImage.blend_rect(lightImage, light_rect, new_grid_position - light_offset)	
	#fogImage.unlock()
	#lightImage.unlock()
	update_fog_image_texture()
	
func update_fog_image_texture():
	fogTexture.create_from_image(fogImage)
	fog.texture = fogTexture

func _input(event):
	if playerNode && playerNode.player.velocity!=Vector2(0,0):
		update_fog(playerNode.player.position)
